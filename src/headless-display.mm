// Local Objective-C++ display helper. Private SidecarCore selectors are checked at runtime.
#import <AppKit/AppKit.h>
#import <Carbon/Carbon.h>
#import <AVFoundation/AVFoundation.h>
#import <CoreGraphics/CoreGraphics.h>
#import <objc/message.h>
#include <dlfcn.h>
#include <sys/file.h>
#include <fcntl.h>
#include <unistd.h>
#include <functional>
#include <initializer_list>
#include <sherpa-onnx/c-api/c-api.h>
#include "native/device-types.h"

@interface NSObject (SidecarRuntime)
+ (id)sharedManager;
+ (NSArray *)allDevicesByForcingFetchFromRelay:(BOOL)refresh;
- (NSArray *)devices;
- (NSArray *)connectedDevices;
- (id)identifier;
- (NSString *)name;
- (NSString *)model;
- (BOOL)isRealityDevice;
- (id)configForDevice:(id)device;
- (id)displayID;
- (void)connectToDevice:(id)device completion:(void (^)(NSError *))completion;
@end
static id manager;
static AVAudioPlayer *voicePlayer;
static dispatch_queue_t speechQueue;
static BOOL speechPending=NO;
static uint64_t speechTicket=0;
static const SherpaOnnxOfflineTts *tts=nullptr;
// Kokoro v1.0 speaker table: 11 = am_adam.
static const int kSpeakerID=11;
static const SherpaOnnxOfflineTts *getTTS(){
 if(tts)return tts;
 NSString *root=[NSBundle.mainBundle.resourcePath stringByAppendingPathComponent:@"kokoro"];
 NSString *model=[root stringByAppendingPathComponent:@"model.int8.onnx"];
 NSString *voices=[root stringByAppendingPathComponent:@"voices.bin"];
 NSString *tokens=[root stringByAppendingPathComponent:@"tokens.txt"];
 NSString *data=[root stringByAppendingPathComponent:@"espeak-ng-data"];
 NSString *lexicon=[root stringByAppendingPathComponent:@"lexicon-us-en.txt"];
 SherpaOnnxOfflineTtsConfig config={};config.model.num_threads=2;config.model.provider="cpu";
 config.model.kokoro.model=model.fileSystemRepresentation;
 config.model.kokoro.voices=voices.fileSystemRepresentation;
 config.model.kokoro.tokens=tokens.fileSystemRepresentation;
 config.model.kokoro.data_dir=data.fileSystemRepresentation;
 config.model.kokoro.lexicon=lexicon.fileSystemRepresentation;
 config.model.kokoro.lang="en";config.model.kokoro.length_scale=1.0f;
 config.max_num_sentences=1;config.silence_scale=0.25f;
 tts=SherpaOnnxCreateOfflineTts(&config);return tts;
}
static BOOL renderSpeech(NSString *text,NSString *path){
 if(!getTTS())return NO;
 SherpaOnnxGenerationConfig config={};config.sid=kSpeakerID;config.speed=1.0f;config.silence_scale=0.25f;
 const SherpaOnnxGeneratedAudio *audio=SherpaOnnxOfflineTtsGenerateWithConfig(tts,text.UTF8String,&config,nullptr,nullptr);
 if(!audio||audio->n<=0){if(audio)SherpaOnnxDestroyOfflineTtsGeneratedAudio(audio);return NO;}
 BOOL ok=SherpaOnnxWriteWave(audio->samples,audio->n,audio->sample_rate,path.fileSystemRepresentation)!=0;
 SherpaOnnxDestroyOfflineTtsGeneratedAudio(audio);return ok;
}
static BOOL busy=NO;
static BOOL uncertain=NO;
static void speak(NSString *text){
 NSString *log=[NSTemporaryDirectory()stringByAppendingPathComponent:@"headless-display.log"];
 FILE *f=fopen(log.fileSystemRepresentation,"a");if(f){fprintf(f,"%s [kokoro/am_adam] %s\n",NSDate.date.description.UTF8String,text.UTF8String);fclose(f);}
 fprintf(stderr,"%s\n",text.UTF8String);
 uint64_t ticket=++speechTicket;speechPending=YES;[voicePlayer stop];
 if(!speechQueue)speechQueue=dispatch_queue_create("local.headless-display.speech",DISPATCH_QUEUE_SERIAL);
 dispatch_async(speechQueue,^{@autoreleasepool{
  static NSMutableDictionary<NSString*,NSData*> *cache=[NSMutableDictionary new];
  NSData *data=cache[text];
  if(!data){
   NSString *path=[NSTemporaryDirectory()stringByAppendingPathComponent:[NSUUID.UUID.UUIDString stringByAppendingString:@".wav"]];
   if(renderSpeech(text,path)){data=[NSData dataWithContentsOfFile:path];if(data){if(cache.count>=32)[cache removeAllObjects];cache[text]=data;}}
   [NSFileManager.defaultManager removeItemAtPath:path error:nil];
  }
  dispatch_async(dispatch_get_main_queue(),^{
   if(ticket!=speechTicket)return;speechPending=NO;
   if(!data){fprintf(stderr,"Kokoro speech generation failed\n");return;}
   NSError *error=nil;voicePlayer=[[AVAudioPlayer alloc]initWithData:data error:&error];
   if(!voicePlayer||![voicePlayer play])fprintf(stderr,"Audio playback failed: %s\n",error.localizedDescription.UTF8String?:"unknown error");
  });
 }});
}
static void pump(double seconds){NSDate *until=[NSDate dateWithTimeIntervalSinceNow:seconds];while(until.timeIntervalSinceNow>0)[[NSRunLoop currentRunLoop]runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.05]];}
#include "native/display-accessibility.h"
static NSString *identity(id d){return [[d identifier] description];}
static BOOL connected(id d){for(id c in [manager connectedDevices])if([identity(c) isEqual:identity(d)])return YES;return NO;}
static BOOL isNativeHeadset(id device){return [device respondsToSelector:@selector(isRealityDevice)]&&[device isRealityDevice];}
static NSArray *nativeDevices(BOOL refresh){
 NSMutableArray *all=[NSMutableArray array];NSMutableSet *seen=[NSMutableSet set];
 NSArray *groups=@[[manager devices]?:@[],[manager connectedDevices]?:@[]];
 for(NSArray *group in groups)for(id d in group){NSString *key=identity(d);if(key.length&&![seen containsObject:key]){[seen addObject:key];[all addObject:d];}}
 Class deviceClass=NSClassFromString(@"SidecarDevice");
 if([deviceClass respondsToSelector:@selector(allDevicesByForcingFetchFromRelay:)]){
  // The relay may know a reality device before the display manager refreshes.
  for(id d in [deviceClass allDevicesByForcingFetchFromRelay:refresh]){NSString *key=identity(d);if(isNativeHeadset(d)&&key.length&&![seen containsObject:key]){[seen addObject:key];[all addObject:d];}}
 }
 return all;
}
static id find(NSString *name){for(id d in nativeDevices(NO))if([[d name]caseInsensitiveCompare:name]==NSOrderedSame)return d;return nil;}
static BOOL nativeDisplayOnline(id device){
 id cfg=[manager configForDevice:device];if(![cfg respondsToSelector:@selector(displayID)])return NO;
 id number=[cfg displayID];return [number isKindOfClass:NSNumber.class]&&[number unsignedIntValue]&&CGDisplayIsOnline([number unsignedIntValue]);
}
static BOOL mirror(id device){
 id cfg=[manager configForDevice:device]; if(![cfg respondsToSelector:@selector(displayID)])return NO;
 NSNumber *number=[cfg displayID]; if(![number isKindOfClass:NSNumber.class])return NO;
 CGDirectDisplayID target=number.unsignedIntValue; if(!target||!CGDisplayIsOnline(target))return NO;
 CGDirectDisplayID ids[32],source=0;uint32_t count=0;CGGetOnlineDisplayList(32,ids,&count);
 for(uint32_t i=0;i<count;i++)if(ids[i]!=target&&CGDisplayIsBuiltin(ids[i])){source=ids[i];break;}
 if(!source){source=CGMainDisplayID();if(source==target)return YES;}
 if(CGDisplayMirrorsDisplay(target)==source||CGDisplayMirrorsDisplay(source)==target)return YES;
 CGDisplayConfigRef config=nullptr;if(CGBeginDisplayConfiguration(&config)!=kCGErrorSuccess)return NO;
 if(CGConfigureDisplayMirrorOfDisplay(config,target,source)!=kCGErrorSuccess){CGCancelDisplayConfiguration(config);return NO;}
 return CGCompleteDisplayConfiguration(config,kCGConfigureForSession)==kCGErrorSuccess;
}
static BOOL attempt(id d){
 NSString *label=[d name]?:@"Display";
 if(connected(d)&&isNativeHeadset(d)){BOOL online=nativeDisplayOnline(d);speak(online?@"Mac Virtual Display is already connected.":@"The native session exists, but its display is not online yet.");return online;}
 if(connected(d)){BOOL mirrored=mirror(d);speak([NSString stringWithFormat:@"%@ is connected.%@",label,mirrored?@"":@" I could not verify its mirror configuration."]);return YES;}
 speak([NSString stringWithFormat:@"Connecting to %@.",label]);
 __block BOOL done=NO;__block NSError *failure=nil;
 [manager connectToDevice:d completion:^(NSError *error){failure=error;done=YES;}];
 NSDate *deadline=[NSDate dateWithTimeIntervalSinceNow:15];while(!done&&deadline.timeIntervalSinceNow>0)pump(.1);
 if(!done){uncertain=YES;speak(@"Connection timed out. Stopping to avoid starting two connections at once.");return NO;}
 if(failure){speak([NSString stringWithFormat:@"%@ connection failed: %@",label,failure.localizedDescription]);return NO;}
 deadline=[NSDate dateWithTimeIntervalSinceNow:5];while(!connected(d)&&deadline.timeIntervalSinceNow>0)pump(.2);
 if(!connected(d)){speak([NSString stringWithFormat:@"%@ did not confirm a connection.",label]);return NO;}
 if(isNativeHeadset(d)){
  deadline=[NSDate dateWithTimeIntervalSinceNow:10];while(!nativeDisplayOnline(d)&&deadline.timeIntervalSinceNow>0)pump(.2);
  BOOL online=nativeDisplayOnline(d);speak(online?@"Mac Virtual Display connected.":@"The native session started, but its display did not come online.");return online;
 }
 BOOL mirrored=mirror(d);speak([NSString stringWithFormat:@"%@ connected.%@",label,mirrored?@"":@" I could not verify its mirror configuration."]);return YES;
}
static NSArray<NSDictionary*> *availableReceivers(void){
 ReceiverMetadataBrowser *observer=[ReceiverMetadataBrowser new];
 NSNetServiceBrowser *browser=[NSNetServiceBrowser new];browser.delegate=observer;browser.includesPeerToPeer=YES;
 [browser searchForServicesOfType:@"_airplay._tcp." inDomain:@"local."];
 NSMutableDictionary<NSString*,NSDictionary*> *records=[NSMutableDictionary dictionary];
 NSArray *sidecar=nativeDevices(NO);
 for(id d in sidecar){
  NSString *name=[d name];if(!name.length)continue;
  NSString *model=[d respondsToSelector:@selector(model)]?[d model]:@"";
  ReceiverKind kind=receiverKind(model,@"");
  if([d respondsToSelector:@selector(isRealityDevice)]&&[d isRealityDevice])kind=ReceiverHeadset;
  records[name.lowercaseString]=@{@"name":name,@"model":model?:@"",@"kind":@(kind)};
 }
 for(NSString *name in airplayNames())if(!records[name.lowercaseString])records[name.lowercaseString]=@{@"name":name,@"model":@"",@"kind":@(ReceiverUnknown)};
 pump(1.5);[browser stop];for(NSNetService *service in observer.services)[service stop];
 for(NSString *key in records.allKeys){NSDictionary *metadata=observer.metadata[key];if(metadata&&[records[key][@"kind"]integerValue]==ReceiverUnknown){NSMutableDictionary *record=[records[key]mutableCopy];[record addEntriesFromDictionary:metadata];records[key]=record;}}
 for(NSString *key in records.allKeys){NSMutableDictionary *record=[records[key]mutableCopy];record[@"type"]=receiverKindName((ReceiverKind)[record[@"kind"]integerValue]);records[key]=record;}
 return [records.allValues sortedArrayUsingComparator:^NSComparisonResult(NSDictionary *a,NSDictionary *b){return compareReceivers(a,b);}];
}
static NSArray<NSString*> *availableNames(void){return [availableReceivers() valueForKey:@"name"];}
static BOOL connectChoice(NSString *choice){
 if(busy){speak(@"A connection is already in progress.");return NO;}busy=YES;uncertain=NO;
 @try{
  for(NSDictionary *receiver in availableReceivers()){
   NSInteger kind=[receiver[@"kind"]integerValue];
   if([choice isEqualToString:@"headset"]&&kind!=ReceiverHeadset)continue;
   if([choice isEqualToString:@"tablet"]&&kind!=ReceiverTablet)continue;
   NSString *name=receiver[@"name"];id d=find(name);
   if(d?attempt(d):connectAirplay(name)){busy=NO;return YES;}
   if(uncertain){busy=NO;return NO;}
  }
  speak(@"No requested display connected. Wake a receiver and try again.");
 }@catch(NSException *e){speak([@"Display API error: " stringByAppendingString:e.reason?:@"unknown error"]);}
 busy=NO;return NO;
}
@interface DisplayApp : NSObject <NSApplicationDelegate>
@property NSStatusItem *item;
@property EventHotKeyRef hotkey;
@property NSArray<NSString*> *choices;
@property NSMutableArray<NSValue*> *choiceKeys;
@property NSTimer *pickerTimer;
@property NSDate *pickerDeadline;
@property BOOL choosing;
- (void)showPicker;
- (void)chooseNumber:(NSUInteger)number;
- (void)cancelPicker:(BOOL)announce;
@end
static DisplayApp *runningApp;
static OSStatus hotkeyHandler(EventHandlerCallRef,EventRef event,void*){
 EventHotKeyID key={};GetEventParameter(event,kEventParamDirectObject,typeEventHotKeyID,nullptr,sizeof(key),nullptr,&key);
 dispatch_async(dispatch_get_main_queue(),^{if(key.signature=='HdDs')[runningApp showPicker];else if(key.signature=='HdPk'){if(key.id==99)[runningApp cancelPicker:YES];else if(key.id==0)[runningApp showPicker];else [runningApp chooseNumber:key.id];}});return noErr;
}
@implementation DisplayApp
- (void)applicationDidFinishLaunching:(NSNotification *)note{
 runningApp=self;self.item=[NSStatusBar.systemStatusBar statusItemWithLength:NSVariableStatusItemLength];self.item.button.title=@"Displays";
 NSMenu *menu=[NSMenu new];
 for(NSArray *row in @[@[@"Choose a display…",@"choose"],@[@"Auto-connect preferred display",@"auto"],@[@"Enable full device discovery…",@"permission"],@[@"Quit",@"quit"]]){
 NSMenuItem *item=[[NSMenuItem alloc]initWithTitle:row[0] action:@selector(chosen:) keyEquivalent:@""];item.target=self;item.representedObject=row[1];[menu addItem:item];}self.item.menu=menu;
 EventTypeSpec spec={kEventClassKeyboard,kEventHotKeyPressed};InstallApplicationEventHandler(hotkeyHandler,1,&spec,nullptr,nullptr);
 EventHotKeyID key={'HdDs',1};EventHotKeyRef ref=nullptr;OSStatus err=RegisterEventHotKey(kVK_ANSI_M,controlKey|optionKey|cmdKey,key,GetApplicationEventTarget(),0,&ref);self.hotkey=ref;
 [NSDistributedNotificationCenter.defaultCenter addObserver:self selector:@selector(requestChooser:) name:@"local.headless-display.choose" object:nil];
 [NSDistributedNotificationCenter.defaultCenter addObserver:self selector:@selector(cancelRequest:) name:@"local.headless-display.cancel" object:nil];
 if(err!=noErr)speak(@"The display hotkey is in use. Use the Displays menu.");else speak(@"Display chooser ready. Press Control Option Command M to hear available displays.");
}
- (void)requestChooser:(NSNotification*)note{[self showPicker];}
- (void)cancelRequest:(NSNotification*)note{[self cancelPicker:YES];}
- (void)cancelPicker:(BOOL)announce{
 self.choosing=NO;[self.pickerTimer invalidate];self.pickerTimer=nil;self.pickerDeadline=nil;
 for(NSValue *v in self.choiceKeys)UnregisterEventHotKey((EventHotKeyRef)v.pointerValue);self.choiceKeys=nil;self.item.button.title=@"Displays";
 if(announce)speak(@"Cancelled.");
}
- (void)showPicker{
 if(busy){speak(@"A display connection is in progress.");return;}
 [self cancelPicker:NO];busy=YES;NSArray *names=availableNames();busy=NO;
 if(!names.count){speak(AXIsProcessTrusted()?@"No mirroring devices are available. Wake your device and try again.":@"No Sidecar devices found. Enable Accessibility for Headless Display to include Vision Pro, Macs and TVs.");return;}
 self.choices=names.count>9?[names subarrayWithRange:NSMakeRange(0,9)]:names;
 self.choiceKeys=[NSMutableArray array];self.choosing=YES;
 const UInt32 codes[]={kVK_ANSI_0,kVK_ANSI_1,kVK_ANSI_2,kVK_ANSI_3,kVK_ANSI_4,kVK_ANSI_5,kVK_ANSI_6,kVK_ANSI_7,kVK_ANSI_8,kVK_ANSI_9,kVK_Escape};
 BOOL registered=YES;
 for(NSUInteger i=0;i<=10;i++){if(i>self.choices.count&&i!=10)continue;EventHotKeyRef ref=nullptr;EventHotKeyID key={'HdPk',(UInt32)(i==10?99:i)};if(RegisterEventHotKey(codes[i],0,key,GetApplicationEventTarget(),0,&ref)!=noErr){registered=NO;break;}[self.choiceKeys addObject:[NSValue valueWithPointer:ref]];}
 if(!registered){[self cancelPicker:NO];speak(@"The number keys could not be registered. Use the Displays menu and try again.");return;}
 self.item.button.title=@"Displays: choose";
 NSMutableString *prompt=[NSMutableString stringWithString:@"Available displays. "];
 [self.choices enumerateObjectsUsingBlock:^(NSString *name,NSUInteger i,BOOL*){[prompt appendFormat:@"%lu. %@. ",(unsigned long)i+1,name];}];
 [prompt appendString:@"Press a number to connect. Zero repeats the list. Escape cancels."];
 if(!AXIsProcessTrusted())[prompt appendString:@" Full discovery needs Accessibility permission."];
 speak(prompt);
 self.pickerTimer=[NSTimer scheduledTimerWithTimeInterval:.5 repeats:YES block:^(NSTimer *){
  if(speechPending||voicePlayer.isPlaying)return;
  if(!self.pickerDeadline)self.pickerDeadline=[NSDate dateWithTimeIntervalSinceNow:30];
  if(self.pickerDeadline.timeIntervalSinceNow<=0)[self cancelPicker:YES];
 }];
}
- (void)chooseNumber:(NSUInteger)number{
 if(!self.choosing||number<1||number>self.choices.count)return;
 NSString *name=self.choices[number-1];[self cancelPicker:NO];busy=YES;
 id device=find(name);if(device)attempt(device);else connectAirplay(name);busy=NO;
}
- (void)chosen:(NSMenuItem*)item{
 NSString *choice=item.representedObject;
 if([choice isEqual:@"quit"]){[self cancelPicker:NO];[NSApp terminate:nil];return;}
 if([choice isEqual:@"permission"]){AXIsProcessTrustedWithOptions((__bridge CFDictionaryRef)@{(__bridge NSString*)kAXTrustedCheckOptionPrompt:@YES});[NSWorkspace.sharedWorkspace openURL:[NSURL URLWithString:@"x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"]];return;}
 if([choice isEqual:@"choose"]){[self showPicker];return;}[self cancelPicker:NO];connectChoice(@"auto");
}
@end
int main(int argc,const char **argv){@autoreleasepool{
 if(!dlopen("/System/Library/PrivateFrameworks/SidecarCore.framework/SidecarCore",RTLD_NOW)){fprintf(stderr,"SidecarCore unavailable\n");return 2;}
 Class cls=NSClassFromString(@"SidecarDisplayManager");if(![cls respondsToSelector:@selector(sharedManager)])return 2;manager=[cls sharedManager];
 for(NSString *s in @[@"devices",@"connectedDevices",@"connectToDevice:completion:",@"configForDevice:"])if(![manager respondsToSelector:NSSelectorFromString(s)]){fprintf(stderr,"Unsupported SidecarCore API\n");return 2;}
 NSString *command=argc>1?@(argv[1]):@"--agent";
 if([command isEqual:@"--list"]){pump(2);NSMutableArray *rows=[NSMutableArray array];NSMutableSet *seen=[NSMutableSet set];NSArray *all=[[manager devices]arrayByAddingObjectsFromArray:[manager connectedDevices]?:@[]];for(id d in all){if([seen containsObject:identity(d)])continue;[seen addObject:identity(d)];id cfg=[manager configForDevice:d];[rows addObject:@{@"name":[d name]?:@"",@"identifier":identity(d)?:@"",@"connected":@(connected(d)),@"displayID":[cfg displayID]?:@0}];}NSData *json=[NSJSONSerialization dataWithJSONObject:rows options:NSJSONWritingPrettyPrinted error:nil];puts([[NSString alloc]initWithData:json encoding:NSUTF8StringEncoding].UTF8String);return 0;}
 if([command isEqual:@"--native-vision"]){
  [NSApplication sharedApplication];id headset=nil;NSDate *deadline=[NSDate dateWithTimeIntervalSinceNow:25];
  do{for(id d in nativeDevices(YES))if(isNativeHeadset(d)){headset=d;break;}if(headset)break;pump(1);}while(deadline.timeIntervalSinceNow>0);
  if(!headset){fprintf(stderr,"No native Vision Pro record was supplied by SidecarRelay. AirPlay discovery is separate; no connection was attempted.\n");return 4;}
  BOOL ok=attempt(headset);while(speechPending||voicePlayer.isPlaying)pump(.05);return ok?0:1;
 }
 if([command isEqual:@"--request-access"]){[NSApplication sharedApplication];BOOL trusted=AXIsProcessTrustedWithOptions((__bridge CFDictionaryRef)@{(__bridge NSString*)kAXTrustedCheckOptionPrompt:@YES});printf("Accessibility: %s\n",trusted?"enabled":"awaiting approval");return trusted?0:3;}
 if([command isEqual:@"--cancel"]){[NSDistributedNotificationCenter.defaultCenter postNotificationName:@"local.headless-display.cancel" object:nil userInfo:nil deliverImmediately:YES];return 0;}
 if([command isEqual:@"--choose"]){[NSDistributedNotificationCenter.defaultCenter postNotificationName:@"local.headless-display.choose" object:nil userInfo:nil deliverImmediately:YES];return 0;}
 if([command isEqual:@"--device-details"]){[NSApplication sharedApplication];NSData *data=[NSJSONSerialization dataWithJSONObject:availableReceivers() options:NSJSONWritingPrettyPrinted error:nil];puts([[NSString alloc]initWithData:data encoding:NSUTF8StringEncoding].UTF8String);return 0;}
 if([command isEqual:@"--devices"]){[NSApplication sharedApplication];NSArray *names=availableNames();NSData *data=[NSJSONSerialization dataWithJSONObject:names options:NSJSONWritingPrettyPrinted error:nil];puts([[NSString alloc]initWithData:data encoding:NSUTF8StringEncoding].UTF8String);return 0;}
 if([command isEqual:@"--connect"]){if(argc!=3)return 2;[NSApplication sharedApplication];NSString *name=@(argv[2]);id d=find(name);BOOL ok=d?attempt(d):connectAirplay(name);while(speechPending||voicePlayer.isPlaying)pump(.05);return ok?0:1;}
 if([command isEqual:@"--render"]){if(argc!=4){fprintf(stderr,"--render TEXT OUTPUT.wav\n");return 2;}return renderSpeech(@(argv[2]),@(argv[3]))?0:1;}
 if([command isEqual:@"--speak"]){if(argc!=3)return 2;speak(@(argv[2]));while(speechPending||voicePlayer.isPlaying)pump(.05);return voicePlayer?0:1;}
 if(![command isEqual:@"--agent"]){NSString *choice=[command isEqual:@"--vision-pro"]?@"headset":[command isEqual:@"--ipad"]?@"tablet":[command isEqual:@"--auto"]?@"auto":nil;if(!choice){fprintf(stderr,"Usage: headless-display --agent | --list | --auto | --vision-pro | --ipad\n");return 2;}BOOL ok=connectChoice(choice);NSDate *speechEnd=[NSDate dateWithTimeIntervalSinceNow:45];while((speechPending||voicePlayer.isPlaying)&&speechEnd.timeIntervalSinceNow>0)pump(.05);return ok?0:1;}
 NSString *lock=[NSTemporaryDirectory()stringByAppendingPathComponent:@"local.headless-display.lock"];int fd=open(lock.fileSystemRepresentation,O_CREAT|O_RDWR,0600);if(fd<0||flock(fd,LOCK_EX|LOCK_NB)!=0){fprintf(stderr,"Display helper is already running\n");return 0;}
 NSApplication *app=[NSApplication sharedApplication];[app setActivationPolicy:NSApplicationActivationPolicyAccessory];DisplayApp *delegate=[DisplayApp new];app.delegate=delegate;[app run];close(fd);
}}

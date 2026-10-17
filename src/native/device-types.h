// Receiver classification uses advertised metadata, never the user's device name.
#import <Foundation/Foundation.h>
typedef NS_ENUM(NSInteger, ReceiverKind){ReceiverHeadset=0,ReceiverTablet=1,ReceiverTV=2,ReceiverMac=3,ReceiverUnknown=4};
static ReceiverKind receiverKind(NSString *model,NSString *manufacturer){
 NSString *m=model.lowercaseString?:@"",*vendor=manufacturer.lowercaseString?:@"";
 if([m containsString:@"realitydevice"]||[m containsString:@"visionpro"]||[m containsString:@"vision pro"])return ReceiverHeadset;
 if([m containsString:@"ipad"])return ReceiverTablet;
 if([m hasPrefix:@"mac"]||[m hasPrefix:@"imac"]||[m containsString:@"com.apple.mac"])return ReceiverMac;
 if([m containsString:@"appletv"]||[m containsString:@"television"]||[m containsString:@"tv"]||[m containsString:@"roku"])return ReceiverTV;
 for(NSString *tvVendor in @[@"samsung",@"lg",@"sony",@"vizio",@"roku",@"hisense",@"tcl"])
  if([vendor isEqualToString:tvVendor])return ReceiverTV;
 return ReceiverUnknown;
}
static NSString *receiverKindName(ReceiverKind kind){return @[@"vision-pro",@"ipad",@"tv",@"mac",@"unknown"][(NSUInteger)kind];}
static NSComparisonResult compareReceivers(NSDictionary *a,NSDictionary *b){
 NSInteger first=[a[@"kind"]integerValue],second=[b[@"kind"]integerValue];
 return first==second?[a[@"name"]localizedCaseInsensitiveCompare:b[@"name"]]:(first<second?NSOrderedAscending:NSOrderedDescending);
}
@interface ReceiverMetadataBrowser : NSObject <NSNetServiceBrowserDelegate,NSNetServiceDelegate>
@property NSMutableArray<NSNetService*> *services;
@property NSMutableDictionary<NSString*,NSDictionary*> *metadata;
@end
@implementation ReceiverMetadataBrowser
- (instancetype)init{self=[super init];if(self){self.services=[NSMutableArray array];self.metadata=[NSMutableDictionary dictionary];}return self;}
- (void)netServiceBrowser:(NSNetServiceBrowser*)browser didFindService:(NSNetService*)service moreComing:(BOOL)moreComing{
 [self.services addObject:service];service.delegate=self;service.includesPeerToPeer=YES;[service resolveWithTimeout:1.5];
}
- (void)netServiceDidResolveAddress:(NSNetService*)service{
 NSDictionary *txt=[NSNetService dictionaryFromTXTRecordData:service.TXTRecordData?:[NSData data]];
 NSString *(^field)(NSString*)=^NSString*(NSString *key){NSData *data=txt[key];return data?[[NSString alloc]initWithData:data encoding:NSUTF8StringEncoding]:@"";};
 NSString *model=field(@"model");if(!model.length)model=field(@"am");
 NSString *vendor=field(@"manufacturer");
 self.metadata[service.name.lowercaseString]=@{@"model":model?:@"",@"kind":@(receiverKind(model,vendor))};
}
@end

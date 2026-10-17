// Native Accessibility bridge for receivers without an exposed connection API.
#import <ApplicationServices/ApplicationServices.h>
static id axGet(id node,CFStringRef key){CFTypeRef value=nullptr;if(!node||AXUIElementCopyAttributeValue((__bridge AXUIElementRef)node,key,&value)!=kAXErrorSuccess)return nil;return CFBridgingRelease(value);}
static NSString *axString(id node,CFStringRef key){id v=axGet(node,key);return [v isKindOfClass:NSString.class]?v:@"";}
static NSArray *axChildren(id node){id v=axGet(node,kAXChildrenAttribute);return [v isKindOfClass:NSArray.class]?v:@[];}
static NSArray *axTree(id root){NSMutableArray *out=[NSMutableArray array];NSMutableArray *queue=[NSMutableArray arrayWithObject:root];for(NSUInteger i=0;i<queue.count&&i<1800;i++){id n=queue[i];[out addObject:n];[queue addObjectsFromArray:axChildren(n)];}return out;}
static BOOL axPress(id node){return node&&AXUIElementPerformAction((__bridge AXUIElementRef)node,kAXPressAction)==kAXErrorSuccess;}
static id settingsAXWindow(void){
 for(NSRunningApplication *app in [NSRunningApplication runningApplicationsWithBundleIdentifier:@"com.apple.systempreferences"]){
  id root=CFBridgingRelease(AXUIElementCreateApplication(app.processIdentifier));AXUIElementSetMessagingTimeout((__bridge AXUIElementRef)root,0.8);
  id windows=axGet(root,kAXWindowsAttribute);if(![windows isKindOfClass:NSArray.class])continue;
  for(id w in windows)if([axString(w,kAXTitleAttribute)isEqualToString:@"Displays"])return w;
 }return nil;
}
static BOOL axDebug(){return getenv("HEADLESS_DISPLAY_DEBUG")!=nullptr;}
static NSDictionary *displayMenu(void){
 if(!AXIsProcessTrusted()){if(axDebug())fprintf(stderr,"AX not trusted\n");return nil;}
 [NSWorkspace.sharedWorkspace openURL:[NSURL URLWithString:@"x-apple.systempreferences:com.apple.Displays-Settings.extension"]];
 for(int attempt=0;attempt<20;attempt++){
  id window=settingsAXWindow();if(window){
   if(axDebug())fprintf(stderr,"Displays window, %lu nodes\n",(unsigned long)axTree(window).count);
   for(id element in axTree(window)){
    NSString *role=axString(element,kAXRoleAttribute),*identifier=axString(element,CFSTR("AXIdentifier"));
    if([role isEqualToString:@"AXMenuButton"]&&([identifier isEqualToString:@"plus"]||[axString(element,kAXDescriptionAttribute) hasPrefix:@"Display settings"])){
     id menu=nil;for(id child in axChildren(element))if([axString(child,kAXRoleAttribute)isEqualToString:@"AXMenu"])menu=child;
     if(axDebug())fprintf(stderr,"Found chooser %s children=%lu\n",identifier.UTF8String,(unsigned long)axChildren(element).count);
     if(!menu){if(!axPress(element))return nil;pump(.2);}
     for(int retry=0;retry<12&&!menu;retry++){for(id child in axChildren(element))if([axString(child,kAXRoleAttribute)isEqualToString:@"AXMenu"])menu=child;if(!menu)pump(.1);}
     if(axDebug())fprintf(stderr,"Menu %s children=%lu\n",menu?"found":"missing",(unsigned long)axChildren(menu).count);
     if(menu)return @{@"menu":menu,@"button":element,@"window":window};
    }
   }
  }pump(.15);
 }return nil;
}
static void closeDisplayMenu(NSDictionary *info){id menu=info[@"menu"];if(menu)AXUIElementPerformAction((__bridge AXUIElementRef)menu,kAXCancelAction);}
static NSString *menuDeviceName(id node){NSString *name=axString(node,kAXTitleAttribute);if(!name.length)name=axString(node,kAXDescriptionAttribute);return name;}
static BOOL airplayConnected(NSString *name){
 for(NSScreen *screen in NSScreen.screens)if([screen.localizedName caseInsensitiveCompare:name]==NSOrderedSame)return YES;
 id window=settingsAXWindow();if(!window)return NO;
 for(id scroll in axTree(window)){
  if(![axString(scroll,kAXRoleAttribute)isEqualToString:@"AXScrollArea"]||![axString(scroll,kAXDescriptionAttribute)isEqualToString:@"Displays"])continue;
  for(id n in axTree(scroll))for(CFStringRef attr : {kAXTitleAttribute,kAXDescriptionAttribute,kAXValueAttribute}){
   NSString *text=axString(n,attr);if([text caseInsensitiveCompare:name]==NSOrderedSame||[text caseInsensitiveCompare:[@"Airplay Video " stringByAppendingString:name]]==NSOrderedSame)return YES;
  }
 }return NO;
}
static NSArray<NSString*> *airplayNames(void){
 NSDictionary *info=displayMenu();if(!info)return @[];
 NSMutableOrderedSet *names=[NSMutableOrderedSet orderedSet];
 if(axDebug())for(id n in axTree(info[@"menu"]))fprintf(stderr,"%s | %s | %s | %s\n",axString(n,kAXRoleAttribute).UTF8String,axString(n,kAXTitleAttribute).UTF8String,axString(n,kAXDescriptionAttribute).UTF8String,axString(n,CFSTR("AXIdentifier")).UTF8String);
 // The live menu changes while discovery runs: take fresh semantic snapshots.
 for(int i=0;i<5;i++){pump(.25);for(id item in axTree(info[@"menu"]))if([axString(item,CFSTR("AXIdentifier"))isEqualToString:@"airplayvideo"]){NSString *name=menuDeviceName(item);if(name.length)[names addObject:name];}}
 closeDisplayMenu(info);return names.array;
}
static BOOL connectAirplay(NSString *name){
 if(!AXIsProcessTrusted()){speak(@"Enable Accessibility for Headless Display to connect this device.");return NO;}
 NSDictionary *info=displayMenu();if(!info){speak(@"I could not open the mirroring controls. Try again.");return NO;}
 if(airplayConnected(name)){closeDisplayMenu(info);speak([name stringByAppendingString:@" is already connected."]);return YES;}
 for(int retry=0;retry<20;retry++){
  for(id item in axTree(info[@"menu"])){
   if(![axString(item,CFSTR("AXIdentifier"))isEqualToString:@"airplayvideo"]||[menuDeviceName(item)caseInsensitiveCompare:name]!=NSOrderedSame)continue;
   NSString *mark=axString(item,CFSTR("AXMenuItemMarkChar"));if(mark.length){closeDisplayMenu(info);speak([name stringByAppendingString:@" is already connected."]);return YES;}
   if(!axPress(item))break;
   speak([@"Connecting to " stringByAppendingString:name]);
   for(int i=0;i<40;i++){pump(.3);if(airplayConnected(name)){speak([name stringByAppendingString:@" connected."]);return YES;}}
   speak([@"I could not confirm the connection to " stringByAppendingString:name]);return NO;
  }pump(.15);
 }
 closeDisplayMenu(info);speak([name stringByAppendingString:@" is no longer available. Open the chooser again."]);return NO;
}

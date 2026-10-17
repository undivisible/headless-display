#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import <objc/message.h>
#include <dlfcn.h>
int main(){@autoreleasepool{
for(NSString *f in @[@"SidecarCore",@"SidecarUI",@"AirPlaySenderKit",@"DisplayServices"]){NSString *p=[NSString stringWithFormat:@"/System/Library/PrivateFrameworks/%@.framework/%@",f,f];dlopen(p.UTF8String,RTLD_NOW|RTLD_LOCAL);}
unsigned count=0; Class *cs=objc_copyClassList(&count);
for(unsigned i=0;i<count;i++){NSString *name=NSStringFromClass(cs[i]);if(!([name containsString:@"Sidecar"]||[name containsString:@"VirtualDisplay"]||[name containsString:@"APSK"]))continue;
printf("CLASS %s\n",name.UTF8String);
for(int meta=0;meta<2;meta++){unsigned n=0;Method *ms=class_copyMethodList(meta?object_getClass(cs[i]):cs[i],&n);for(unsigned j=0;j<n;j++)printf("%c %s %s\n",meta?'+':'-',sel_getName(method_getName(ms[j])),method_getTypeEncoding(ms[j]));free(ms);}}
free(cs);
Class c=NSClassFromString(@"SidecarDisplayManager");id m=((id(*)(id,SEL))objc_msgSend)(c,sel_registerName("sharedManager"));
for(id d in [m valueForKey:@"devices"]) NSLog(@"device model=%@ reality=%@",[d valueForKey:@"model"],[d valueForKey:@"isRealityDevice"]);
}}

#import <Foundation/Foundation.h>
#include <cassert>
#include "../src/native/device-types.h"
int main(){@autoreleasepool{
 assert(receiverKind(@"RealityDevice14,1",@"")==ReceiverHeadset);
 assert(receiverKind(@"iPad14,3",@"")==ReceiverTablet);
 assert(receiverKind(@"AppleTV11,1",@"")==ReceiverTV);
 assert(receiverKind(@"MacBookPro18,3",@"")==ReceiverMac);
 assert(receiverKind(@"Panel123",@"LG")==ReceiverTV);
 assert(receiverKind(@"Unrecognized123",@"")==ReceiverUnknown);
 NSArray *receivers=@[@{@"name":@"Alpha",@"kind":@(ReceiverMac)},@{@"name":@"Zed",@"kind":@(ReceiverHeadset)},@{@"name":@"Other",@"kind":@(ReceiverUnknown)},@{@"name":@"Yard",@"kind":@(ReceiverTablet)},@{@"name":@"Room",@"kind":@(ReceiverTV)}];
 NSArray *sorted=[receivers sortedArrayUsingComparator:^NSComparisonResult(NSDictionary *a,NSDictionary *b){return compareReceivers(a,b);}];
 NSArray *expected=@[@"Zed",@"Yard",@"Room",@"Alpha",@"Other"];
 assert([[sorted valueForKey:@"name"]isEqualToArray:expected]);
 assert(compareReceivers(@{@"name":@"Alpha",@"kind":@(ReceiverTV)},@{@"name":@"Zed",@"kind":@(ReceiverTV)})==NSOrderedAscending);
 puts("Device metadata classification and priority passed.");
}}

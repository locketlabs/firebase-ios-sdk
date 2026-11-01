/*
 * Copyright 2026 Google LLC
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

#import <XCTest/XCTest.h>

#import "FirebaseRemoteConfig/Sources/RCNConfigRealtime.h"

// Exercise the SDK's parser without configuring an app, database or network stream.
@interface RCNParserRealtime : RCNConfigRealtime
@property(nonatomic) NSUInteger responseCount;
@property(nonatomic, strong) NSDictionary *response;
@property(nonatomic, strong) NSError *responseError;
@end

@implementation RCNParserRealtime
- (void)evaluateStreamResponse:(NSDictionary *)response error:(NSError *)error {
  self.responseCount++;
  self.response = response;
  self.responseError = error;
}
@end

@interface RCNConfigRealtimeParserTest : XCTestCase
@end

@implementation RCNConfigRealtimeParserTest
- (void)testInvalidUTF8IsIgnoredAndNextUpdateIsParsed {
  RCNParserRealtime *realtime = [[RCNParserRealtime alloc] init];
  NSURLSession *session = [NSURLSession sharedSession];
  NSURLSessionDataTask *task =
      [session dataTaskWithURL:[NSURL URLWithString:@"https://example.invalid"]];
  const unsigned char invalidBytes[] = {0xFF, 0xFE, '{', '}'};
  const unsigned char truncatedBytes[] = {'{', '"', 'x', '"', ':', '"', 0xE2};
  NSArray<NSData *> *invalidChunks = @[
    [NSData dataWithBytes:invalidBytes length:sizeof(invalidBytes)],
    [NSData dataWithBytes:truncatedBytes length:sizeof(truncatedBytes)],
  ];
  for (NSData *chunk in invalidChunks) {
    XCTAssertNoThrow([realtime URLSession:session dataTask:task didReceiveData:chunk]);
  }
  XCTAssertEqual(realtime.responseCount, 0U);

  NSDictionary *response = @{@"latestTemplateVersionNumber" : @42};
  NSData *validData = [NSJSONSerialization dataWithJSONObject:response options:0 error:nil];
  [realtime URLSession:session dataTask:task didReceiveData:validData];
  XCTAssertEqual(realtime.responseCount, 1U);
  XCTAssertEqualObjects(realtime.response, response);
  XCTAssertNil(realtime.responseError);
}
@end

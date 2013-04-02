//
//  HTTPClientSuite.m
//  JSONModelDemo_iOS
//
//  Created by Marin Todorov on 3/26/13.
//  Copyright (c) 2013 Underplot ltd. All rights reserved.
//

#import "HTTPClientSuite.h"

#import "NestedModel.h"
#import "ImageModel.h"

#import "JSONModel+networking.h"
#import "MockNSURLConnection.h"
#import "MTTestSemaphor.h"

@implementation HTTPClientSuite
{
    NSString* jsonContents;
}

-(void)setUp
{
    [super setUp];
    
    NSString* filePath = [[NSBundle bundleForClass:[JSONModel class]].resourcePath stringByAppendingPathComponent:@"nestedData.json"];
    jsonContents = [NSString stringWithContentsOfFile:filePath encoding:NSUTF8StringEncoding error:nil];
    
    NSAssert(jsonContents, @"Can't fetch test data file contents.");
}

-(void)testRequestHeaders
{
    NSString* headerName = @"CustomHeader";
    NSString* headerValue = @"CustomValue";
    NSMutableDictionary* headers = [JSONHTTPClient requestHeaders];
    headers[headerName] = headerValue;
    
    //check if the header is saved
    NSMutableDictionary* newHeadersReference = [JSONHTTPClient requestHeaders];
    NSAssert([headerValue isEqualToString: newHeadersReference[headerName]], @"the custom header was not persisted");
    
    //check if the header is sent along the http request
    NSString* jsonURLString = @"http://localhost/test.json?testRequestHeaders";
    NSString* semaphorKey = @"testRequestHeaders";
    
    [JSONHTTPClient postJSONFromURLWithString:jsonURLString
                                       params:nil
                                   completion:^(NSDictionary *json, JSONModelError *err) {
                                       NSURLRequest* request = [NSURLConnection lastRequest];
                                       NSAssert([[request valueForHTTPHeaderField:headerName] isEqualToString: headerValue], @"the custom header was not sent along the http request");
                                       
                                       [[MTTestSemaphor semaphore] lift: semaphorKey];
                                   }];
    
    [[MTTestSemaphor semaphore] waitForKey: semaphorKey];
    
}

-(void)testContentType
{
    NSString* jsonURLString = @"http://localhost/test.json?testContentType";
    NSString* semaphorKey = @"testContentType";
    NSString* ctype = @"text/plain";
    
    [JSONHTTPClient setRequestContentType: ctype];
    
    [JSONHTTPClient postJSONFromURLWithString:jsonURLString
                                       params:nil
                                   completion:^(NSDictionary *json, JSONModelError *err) {
                                       NSURLRequest* request = [NSURLConnection lastRequest];
                                       NSAssert([[request valueForHTTPHeaderField:@"Content-type"] hasPrefix:ctype], @"request content type was not application/JSON");
                                       
                                       [[MTTestSemaphor semaphore] lift: semaphorKey];
                                       [JSONHTTPClient setRequestContentType:kContentTypeAutomatic];
                                   }];
    
    [[MTTestSemaphor semaphore] waitForKey: semaphorKey];
}

-(void)testCachingPolicy
{
    //check if the header is sent along the http request
    NSString* jsonURLString = @"http://localhost/test.json?case=testCachingPolicy";
    NSString* semaphorKey = @"testCachingPolicy";
    
    [JSONHTTPClient setCachingPolicy:NSURLCacheStorageAllowed];
    
    [JSONHTTPClient postJSONFromURLWithString:jsonURLString
                                       params:nil
                                   completion:^(NSDictionary *json, JSONModelError *err) {

                                       NSURLRequest* request = [NSURLConnection lastRequest];
                                       
                                       NSLog(@"request: %@", request.URL.absoluteString);
                                       NSLog(@"keys active: %@", [[MTTestSemaphor semaphore] flags]);
                                       
                                       NSAssert(request.cachePolicy==NSURLCacheStorageAllowed, @"user set caching policy was not set in request");
                                       
                                       [[MTTestSemaphor semaphore] lift: semaphorKey];
                                   }];
    
    [[MTTestSemaphor semaphore] waitForKey: semaphorKey];
}

-(void)aaatestRequestTimeout
{
    //check if the header is sent along the http request
    NSString* jsonURLString = @"http://localhost/test.json?testRequestTimeout";
    NSString* semaphorKey = @"testRequestTimeout";
    
    //the request will take 10 seconds
    [NSURLConnection setResponseDelay: 10];

    //set the client timeout for 5 seconds
    [JSONHTTPClient setTimeoutInSeconds:1];
    [JSONHTTPClient postJSONFromURLWithString:jsonURLString
                                       params:nil
                                   completion:^(NSDictionary *json, JSONModelError *err) {
                                       NSURLRequest* request = [NSURLConnection lastRequest];

                                       NSLog(@"then %@",[NSDate date]);
                                       
                                       
                                       [[MTTestSemaphor semaphore] lift: semaphorKey];
                                   }];
    
    [[MTTestSemaphor semaphore] waitForKey: semaphorKey];    
}

-(void)testGetJSONFromURLNoParams
{
    NSString* jsonURLString = @"http://localhost/test.json?testGetJSONFromURLNoParams";
    NSString* semaphorKey = @"testGetJSONFromURLNoParams";
    NSURLResponse* response = [[NSURLResponse alloc] initWithURL: [NSURL URLWithString:jsonURLString]
                                                        MIMEType: @"application/json"
                                           expectedContentLength: [jsonContents length]
                                                textEncodingName: @"UTF-8"];
    
    [NSURLConnection setNextResponse:response data:[jsonContents dataUsingEncoding:NSUTF8StringEncoding] error:nil];
    
    [JSONHTTPClient getJSONFromURLWithString:jsonURLString
                                  completion:^(NSDictionary *json, JSONModelError *err) {
                                      
                                      //check block parameters
                                      NSAssert(json, @"getJSONFromURLWithString:completion: returned nil, object expected");
                                      NSAssert(!err, @"getJSONFromURLWithString:completion: returned error, nil error expected");
                                      
                                      //check JSON validity
                                      NestedModel* model = [[NestedModel alloc] initWithDictionary:json error:nil];
                                      NSAssert(model, @"getJSONFromURLWithString:completion: got invalid response and model is not initialized properly");
                                      
                                      //check the request
                                      NSURLRequest* request = [NSURLConnection lastRequest];
                                      NSAssert([request.URL.absoluteString isEqualToString: jsonURLString], @"request.URL did not match the request URL");
                                      
                                      //release the semaphore lock
                                      [[MTTestSemaphor semaphore] lift: semaphorKey];
                                  }];
    
    [[MTTestSemaphor semaphore] waitForKey: semaphorKey];
}

-(void)testGetJSONFromURLWithParams
{
    NSString* jsonURLString = @"http://localhost/test.json?testGetJSONFromURLWithParams";
    NSString* semaphorKey = @"testGetJSONFromURLWithParams";
    NSURLResponse* response = [[NSURLResponse alloc] initWithURL: [NSURL URLWithString:jsonURLString]
                                                        MIMEType: @"application/json"
                                           expectedContentLength: [jsonContents length]
                                                textEncodingName: @"UTF-8"];
    
    [NSURLConnection setNextResponse:response data:[jsonContents dataUsingEncoding:NSUTF8StringEncoding] error:nil];
    
    [JSONHTTPClient getJSONFromURLWithString:jsonURLString
                                      params:@{@"key1":@"param1",@"key2":@"pa!?&r am2"}
                                  completion:^(NSDictionary *json, JSONModelError *err) {

                                      //check block parameters
                                      NSAssert(json, @"getJSONFromURLWithString:completion: returned nil, object expected");
                                      NSAssert(!err, @"getJSONFromURLWithString:completion: returned error, nil error expected");
                                      
                                      //check JSON validity
                                      NestedModel* model = [[NestedModel alloc] initWithDictionary:json error:nil];
                                      NSAssert(model, @"getJSONFromURLWithString:completion: got invalid response and model is not initialized properly");
                                      
                                      //check the request
                                      NSURLRequest* request = [NSURLConnection lastRequest];
                                      NSAssert([request.URL.absoluteString isEqualToString: @"http://localhost/test.json?testGetJSONFromURLWithParams&key2=pa%21%3F%26r%20am2&key1=param1"], @"request.URL did not match the request URL");
                                      
                                      //release the semaphore lock
                                      [[MTTestSemaphor semaphore] lift: semaphorKey];
                                  }];
    
    [[MTTestSemaphor semaphore] waitForKey: semaphorKey];
}

-(void)testPostJSONWithParams
{
    NSString* jsonURLString = @"http://localhost/test.json?testPostJSONWithParams";
    NSString* semaphorKey = @"testPostJSONWithParams";
    NSURLResponse* response = [[NSURLResponse alloc] initWithURL: [NSURL URLWithString:jsonURLString]
                                                        MIMEType: @"application/json"
                                           expectedContentLength: [jsonContents length]
                                                textEncodingName: @"UTF-8"];
    
    [NSURLConnection setNextResponse:response data:[jsonContents dataUsingEncoding:NSUTF8StringEncoding] error:nil];
    
    [JSONHTTPClient postJSONFromURLWithString:jsonURLString
                                      params:@{@"key1":@"param1",@"key2":@"pa!?&r am2"}
                                  completion:^(NSDictionary *json, JSONModelError *err) {
                                      
                                      //check block parameters
                                      NSAssert(json, @"getJSONFromURLWithString:completion: returned nil, object expected");
                                      NSAssert(!err, @"getJSONFromURLWithString:completion: returned error, nil error expected");
                                      
                                      //check JSON validity
                                      NestedModel* model = [[NestedModel alloc] initWithDictionary:json error:nil];
                                      NSAssert(model, @"getJSONFromURLWithString:completion: got invalid response and model is not initialized properly");
                                      
                                      //check the request
                                      NSURLRequest* request = [NSURLConnection lastRequest];
                                      NSString* paramsSent = [[NSString alloc] initWithData:[request HTTPBody] encoding:NSUTF8StringEncoding];
                                      NSAssert([request.URL.absoluteString isEqualToString: jsonURLString], @"request.URL is not the given URL");
                                      NSAssert([paramsSent isEqualToString: @"key2=pa%21%3F%26r%20am2&key1=param1"], @"request body data did not match the post encoded params");
                                      
                                      //release the semaphore lock
                                      [[MTTestSemaphor semaphore] lift: semaphorKey];
                                  }];
    
    [[MTTestSemaphor semaphore] waitForKey: semaphorKey];

}

-(void)testPostJSONWithBodyText
{
    NSString* jsonURLString = @"http://localhost/test.json?testPostJSONWithBodyText";
    NSString* semaphorKey = @"testPostJSONWithBodyText";
    NSURLResponse* response = [[NSURLResponse alloc] initWithURL: [NSURL URLWithString:jsonURLString]
                                                        MIMEType: @"application/json"
                                           expectedContentLength: [jsonContents length]
                                                textEncodingName: @"UTF-8"];
    
    [NSURLConnection setNextResponse:response data:[jsonContents dataUsingEncoding:NSUTF8StringEncoding] error:nil];
    
    [JSONHTTPClient postJSONFromURLWithString:jsonURLString
                                   bodyString:@"{clear text post body}"
                                   completion:^(NSDictionary *json, JSONModelError *err) {
                                       
                                       //check block parameters
                                       NSAssert(json, @"getJSONFromURLWithString:completion: returned nil, object expected");
                                       NSAssert(!err, @"getJSONFromURLWithString:completion: returned error, nil error expected");
                                       
                                       //check JSON validity
                                       NestedModel* model = [[NestedModel alloc] initWithDictionary:json error:nil];
                                       NSAssert(model, @"getJSONFromURLWithString:completion: got invalid response and model is not initialized properly");
                                       
                                       //check the request
                                       NSURLRequest* request = [NSURLConnection lastRequest];
                                       NSString* paramsSent = [[NSString alloc] initWithData:[request HTTPBody] encoding:NSUTF8StringEncoding];
                                       NSAssert([request.URL.absoluteString isEqualToString: jsonURLString], @"request.URL is not the given URL");
                                       NSAssert([paramsSent isEqualToString: @"{clear text post body}"], @"post body data did not match the sent text");
                                       
                                       //release the semaphore lock
                                       [[MTTestSemaphor semaphore] lift: semaphorKey];
                                   }];
    
    [[MTTestSemaphor semaphore] waitForKey: semaphorKey];
    
}

-(void)testPostJSONWithBodyData
{
    NSString* jsonURLString = @"http://localhost/test.json?testPostJSONWithBodyData";
    NSString* semaphorKey = @"testPostJSONWithBodyData";
    NSURLResponse* response = [[NSURLResponse alloc] initWithURL: [NSURL URLWithString:jsonURLString]
                                                        MIMEType: @"application/json"
                                           expectedContentLength: [jsonContents length]
                                                textEncodingName: @"UTF-8"];
    
    [NSURLConnection setNextResponse:response data:[jsonContents dataUsingEncoding:NSUTF8StringEncoding] error:nil];
    
    NSData* postData = [@"POSTDATA" dataUsingEncoding:NSUTF8StringEncoding];
    
    [JSONHTTPClient postJSONFromURLWithString:jsonURLString
                                     bodyData:postData
                                   completion:^(NSDictionary *json, JSONModelError *err) {
                                       
                                       //check block parameters
                                       NSAssert(json, @"getJSONFromURLWithString:completion: returned nil, object expected");
                                       NSAssert(!err, @"getJSONFromURLWithString:completion: returned error, nil error expected");
                                       
                                       //check JSON validity
                                       NestedModel* model = [[NestedModel alloc] initWithDictionary:json error:nil];
                                       NSAssert(model, @"getJSONFromURLWithString:completion: got invalid response and model is not initialized properly");
                                       
                                       //check the request
                                       NSURLRequest* request = [NSURLConnection lastRequest];
                                       NSAssert([request.URL.absoluteString isEqualToString: jsonURLString], @"request.URL is not the given URL");
                                       NSAssert([postData isEqualToData:[request HTTPBody]], @"post data did not match the sent post data");
                                       
                                       //release the semaphore lock
                                       [[MTTestSemaphor semaphore] lift: semaphorKey];
                                   }];
    
    [[MTTestSemaphor semaphore] waitForKey: semaphorKey];
}

-(void)testPostJSONWithError
{
    NSString* jsonURLString = @"http://localhost/test.json?testPostJSONWithError";
    NSString* semaphorKey = @"testPostJSONWithBodyData";
    NSURLResponse* response = [[NSURLResponse alloc] initWithURL: [NSURL URLWithString:jsonURLString]
                                                        MIMEType: @"application/json"
                                           expectedContentLength: [jsonContents length]
                                                textEncodingName: @"UTF-8"];
    
    [NSURLConnection setNextResponse:response data:nil error:[NSError errorWithDomain:@"HTTP" code:1000 userInfo:@{}]];
    
    NSData* postData = [@"POSTDATA" dataUsingEncoding:NSUTF8StringEncoding];
    
    [JSONHTTPClient postJSONFromURLWithString:jsonURLString
                                     bodyData:postData
                                   completion:^(NSDictionary *json, JSONModelError *err) {
                                       
                                       //check block parameters
                                       NSAssert(!json, @"getJSONFromURLWithString:completion: returned nil, object expected");
                                       NSAssert(err, @"getJSONFromURLWithString:completion: returned error, nil error expected");
                                       NSAssert(err.code==kJSONModelErrorBadResponse, @"Error code didn't match kJSONModelErrorBadResponse");
                                       
                                       //release the semaphore lock
                                       [[MTTestSemaphor semaphore] lift: semaphorKey];
                                   }];
    
    [[MTTestSemaphor semaphore] waitForKey: semaphorKey];
}


@end
//
//  FastSocketTest.h
//  Copyright (c) 2011-2013 Daniel Reese <dan@danandcheryl.com>
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.
//

#import "FastSocket.h"
#import "FastServerSocket.h"
#import <XCTest/XCTest.h>


@interface FastSocketTest : XCTestCase {
	FastSocket *client;
	FastServerSocket *server;
}

@end


@implementation FastSocketTest

- (void)setUp {
	server = [[FastServerSocket alloc] initWithPort:@"34567"];
	client = [[FastSocket alloc] initWithHost:@"localhost" andPort:@"34567"];
}

- (void)tearDown {
	[client close];
	[server close];
}

#pragma mark Tests

- (void)testConnect {
	// No failures yet.
	XCTAssertNil([client lastError]);
	
	// Nothing is listening yet.
	XCTAssertFalse([client connect]);
	XCTAssertNotNil([client lastError]);
	
	// Spawn server thread.
	[NSThread detachNewThreadSelector:@selector(simpleListen:) toTarget:self withObject:nil];
	[NSThread sleepUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.1]];
	
	// Connection should now succeed.
	XCTAssertTrue([client connect]);
	//STAssertNil([client lastError], @"Last error should be nil"); // TODO: Not sure if this should be cleared out or just left alone.
}

- (void)testConnectWithDefaultTimeout {
	// Connect to a non-routable IP address. See http://stackoverflow.com/a/904609/209371
	[client close];
	client = [[FastSocket alloc] initWithHost:@"10.255.255.1" andPort:@"81"];
	
	// Connection should timeout.
	NSTimeInterval startTime = [NSDate timeIntervalSinceReferenceDate];
	XCTAssertFalse([client connect]);
	NSTimeInterval endTime = [NSDate timeIntervalSinceReferenceDate];
	XCTAssertNotNil([client lastError]);
	
	// Default timeout is 75 seconds on my machine.
	NSTimeInterval actualTime = endTime - startTime;
	XCTAssertTrue(actualTime >= 75.0, @"timeout was %.2f", actualTime);
	XCTAssertTrue(actualTime < 76.3, @"timeout was %.2f", actualTime);
}

- (void)testConnectWithCustomTimeout {
	// Connect to a non-routable IP address. See http://stackoverflow.com/a/904609/209371
	[client close];
	client = [[FastSocket alloc] initWithHost:@"10.255.255.1" andPort:@"81"];
	
	// Connection should timeout.
	NSTimeInterval startTime = [NSDate timeIntervalSinceReferenceDate];
	XCTAssertFalse([client connect:10]);
	NSTimeInterval endTime = [NSDate timeIntervalSinceReferenceDate];
	XCTAssertNotNil([client lastError]);
	
	// Check the duration of the timeout.
	NSTimeInterval actualTime = endTime - startTime;
	XCTAssertTrue(actualTime >= 9.9, @"timeout was %.2f", actualTime);
	XCTAssertTrue(actualTime < 10.1, @"timeout was %.2f", actualTime);
}

- (void)testIsConnected {
	// Spawn server thread.
	[NSThread detachNewThreadSelector:@selector(simpleListen:) toTarget:self withObject:nil];
	[NSThread sleepUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.1]];
	
	// Check connected state before and after connecting, and after closing.
	XCTAssertFalse([client isConnected]);
	XCTAssertTrue([client connect]);
	XCTAssertTrue([client isConnected]);
	XCTAssertTrue([client close]);
	XCTAssertFalse([client isConnected]);
	
	// Close server socket and verify that the client knows it's no longer connected.
	XCTAssertTrue([client connect]);
	XCTAssertTrue([client isConnected]);
	XCTAssertTrue([server close]);
	[NSThread sleepUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.2]];
	XCTAssertFalse([client isConnected]);
}

- (void)testTimeoutBefore {
	// Spawn server thread.
	[NSThread detachNewThreadSelector:@selector(simpleListen:) toTarget:self withObject:nil];
	[NSThread sleepUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.1]];
	
	// Set value before connect.
	XCTAssertTrue([client setTimeout:100]);
	XCTAssertTrue([client connect]);
	XCTAssertEqual([client timeout], 100L);
	XCTAssertTrue([client close]);
}

- (void)testTimeoutAfter {
	// Spawn server thread.
	[NSThread detachNewThreadSelector:@selector(simpleListen:) toTarget:self withObject:nil];
	[NSThread sleepUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.1]];
	
	// Set value after connect.
	XCTAssertTrue([client connect]);
	XCTAssertTrue([client setTimeout:100]);
	XCTAssertEqual([client timeout], 100L);
	XCTAssertTrue([client close]);
}

- (void)testTimeoutMultipleBefore {
	// Spawn server thread.
	[NSThread detachNewThreadSelector:@selector(simpleListen:) toTarget:self withObject:nil];
	[NSThread sleepUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.1]];
	
	// Set value twice before connect.
	XCTAssertTrue([client setTimeout:100]);
	XCTAssertTrue([client setTimeout:101]);
	XCTAssertTrue([client connect]);
	XCTAssertEqual([client timeout], 101L);
	XCTAssertTrue([client close]);
}

- (void)testTimeoutMultipleAfter {
	// Spawn server thread.
	[NSThread detachNewThreadSelector:@selector(simpleListen:) toTarget:self withObject:nil];
	[NSThread sleepUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.1]];
	
	// Set value twice after connect.
	XCTAssertTrue([client connect]);
	XCTAssertTrue([client setTimeout:100]);
	XCTAssertTrue([client setTimeout:101]);
	XCTAssertEqual([client timeout], 101L);
	XCTAssertTrue([client close]);
}

- (void)testSegmentSizeBefore {
	// Spawn server thread.
	[NSThread detachNewThreadSelector:@selector(simpleListen:) toTarget:self withObject:nil];
	[NSThread sleepUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.1]];
	
	// Set value before connect.
	XCTAssertTrue([client setSegmentSize:10000]);
	XCTAssertTrue([client connect]);
	XCTAssertEqual([client segmentSize], 10000);
	XCTAssertTrue([client close]);
}

- (void)testSegmentSizeAfter {
	// Spawn server thread.
	[NSThread detachNewThreadSelector:@selector(simpleListen:) toTarget:self withObject:nil];
	[NSThread sleepUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.1]];
	
	// Set value after connect.
	XCTAssertTrue([client connect]);
	XCTAssertTrue([client setSegmentSize:10000]);
	XCTAssertEqual([client segmentSize], 10000);
	XCTAssertTrue([client close]);
}

- (void)testSegmentSizeMultipleBefore {
	// Spawn server thread.
	[NSThread detachNewThreadSelector:@selector(simpleListen:) toTarget:self withObject:nil];
	[NSThread sleepUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.1]];
	
	// Set value twice before connect.
	XCTAssertTrue([client setSegmentSize:10000]);
	XCTAssertTrue([client setSegmentSize:10001]);
	XCTAssertTrue([client connect]);
	XCTAssertEqual([client segmentSize], 10001);
	XCTAssertTrue([client close]);
}

- (void)testSegmentSizeMultipleAfter {
	// Spawn server thread.
	[NSThread detachNewThreadSelector:@selector(simpleListen:) toTarget:self withObject:nil];
	[NSThread sleepUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.1]];
	
	// Set value twice after connect.
	XCTAssertTrue([client connect]);
	XCTAssertTrue([client setSegmentSize:10000]);
	XCTAssertFalse([client setSegmentSize:10001]);
	XCTAssertTrue([client setSegmentSize:9999]);
	XCTAssertEqual([client segmentSize], 9999);
	XCTAssertTrue([client close]);
}

- (void)testSendingAndReceivingBytes {
	// Spawn server thread.
	[NSThread detachNewThreadSelector:@selector(listenAndRepeat:) toTarget:self withObject:nil];
	[NSThread sleepUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.1]];
	
	// Send byte array.
	long len = 10;
	unsigned char sent[] = {1, -2, 3, -4, 5, -6, 7, -8, 9, 0};
	[client connect];
	XCTAssertEqual([client sendBytes:sent count:len], len, @"send error: %@", [client lastError]);
	[[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.1]];
	
	// Receive byte array.
	unsigned char received[len];
	XCTAssertEqual([client receiveBytes:received count:len], len, @"receive error: %@", [client lastError]);
	
	// Compare results.
	XCTAssertEqual(memcmp(sent, received, len), 0);
}

- (void)testSendingAndReceivingRandomBytes {
	// Spawn server thread.
	[NSThread detachNewThreadSelector:@selector(listenAndRepeat:) toTarget:self withObject:nil];
	[NSThread sleepUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.1]];
	
	// Create a random byte array larger than the buffer.
	long len = 1024 * 10 * 200;
	unsigned char sent[len];
	for (int i = 0; i < len; ++i) {
		sent[i] = (unsigned char)(random() % 256);
	}
	NSLog(@"sending %li bytes", len);
	
	// Send the array.
	[client connect];
	XCTAssertEqual([client sendBytes:sent count:len], len, @"send error: %@", [client lastError]);
	[[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.1]];
	
	// Receive the array.
	unsigned char received[len];
	XCTAssertEqual([client receiveBytes:received count:len], len, @"receive error: %@", [client lastError]);
	
	// Compare results.
	XCTAssertEqual(memcmp(sent, received, len), 0);
}

- (void)testSendingAndReceivingStrings {
	// Spawn server thread.
	[NSThread detachNewThreadSelector:@selector(listenAndRepeat:) toTarget:self withObject:nil];
	[NSThread sleepUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.1]];
	[client connect];
	
	// Send the string.
	NSString *original = @"This is å striñg to tëst séndîng. 😎";
	NSData *data = [original dataUsingEncoding:NSUTF8StringEncoding];
	long len = [data length];
	XCTAssertEqual([client sendBytes:[data bytes] count:len], len, @"send error: %@", [client lastError]);
	[[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.1]];
	
	// Receive the string.
	char bytes[len];
	XCTAssertEqual([client receiveBytes:bytes count:len], len, @"receive error: %@", [client lastError]);
	NSString *received = [[NSString alloc] initWithBytes:bytes length:len encoding:NSUTF8StringEncoding];
	
	// Compare results.
	XCTAssertEqualObjects(received, original);
}

#pragma mark Helpers

- (void)simpleListen:(id)obj {
	@autoreleasepool {
		[server listen]; // Incoming connections just queue up.
	}
}

- (void)listenAndRepeat:(id)obj {
	@autoreleasepool {
		NSLog(@"started listening");
		[server listen];
		
		FastSocket *incoming = [server accept];
		if (!incoming) {
			NSLog(@"accept error: %@", [server lastError]);
			return;
		}
		
		// Read some bytes then echo them back.
		int bufSize = 2048;
		unsigned char buf[bufSize];
		long count = 0;
		do {
			// Read bytes.
			count = [incoming receiveBytes:buf limit:bufSize];
			
			// Write bytes.
			long remaining = count;
			while (remaining > 0) {
				count = [incoming sendBytes:buf count:remaining];
				remaining -= count;
			}
			
			// Allow other threads to work.
			[[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.1]];
		} while (count > 0);
		
		XCTAssertEqual(count, 0, @"error: %@", [incoming lastError]);
	}
}

@end

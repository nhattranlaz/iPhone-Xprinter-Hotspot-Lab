//
//  ESPUDPSocketClient.m
//  EspTouchDemo
//
//  Created by fby on 4/13/15.
//  Copyright (c) 2015 fby. All rights reserved.
//

#import "ESPUDPSocketClient.h"
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <ifaddrs.h>
#include <net/if.h>
#include <errno.h>
#import <netdb.h>
#include "ESPTouchTask.h"
#import "ESP_NetUtil.h"

#define SOCKET_NULL     -1

@interface ESPUDPSocketClient ()

@property(nonatomic, assign) int _sck_fd4;
@property(nonatomic, assign) int _sck_fd6;
@property(nonatomic, assign) BOOL _isStop;
// it is used to check whether the socket is closed already to prevent close more than once.
// especially, when you close the socket second time, it is created just now, it will crash.
//
//      // suppose fd1 = 4, fd1 belong to obj1
// e.g. int fd1 = socket(AF_INET,SOCK_DRAM,0);
//      close(fd1);
//
//      // suppose fd2 = 4 as well, fd2 belong to obj2
//      int fd2 = socket(AF_INET,SOCK_DRAM,0);
//
//      // obj1's dealloc() is called by system, so
//      close(fd1);
//
//      // Amazing!!! at the moment, fd2 is close by others
//
@property(nonatomic,assign) volatile BOOL _isClosed;
// it is used to lock the close method
@property(nonatomic,strong) volatile NSLock *_lock;

@end

@implementation ESPUDPSocketClient

- (id)init
{
    self = [super init];
    if (self)
    {
        self._isStop = NO;
        self._sck_fd4 = SOCKET_NULL;
        self._sck_fd6 = SOCKET_NULL;
        self._sck_fd4 = socket(AF_INET,SOCK_DGRAM,0);
        if (DEBUG_ON)
        {
            NSLog(@"##########################client init() _sck_fd4=%d",self._sck_fd4);
        }
        if (self._sck_fd4 < 0)
        {
            if (DEBUG_ON)
            {
                perror("client: init() _skd_fd4 init fail\n");
            }
            return nil;
        }
        self._sck_fd6 = socket(AF_INET6,SOCK_DGRAM,0);
        if (DEBUG_ON)
        {
            NSLog(@"##########################client init() _sck_fd6=%d",self._sck_fd6);
        }
        if (self._sck_fd6 < 0)
        {
            if (DEBUG_ON)
            {
                perror("client: init() _skd_fd6 init fail\n");
            }
            return nil;
        }
    }
    return self;
}

// make sure the socket will be closed sometime
- (void)dealloc
{
    if (DEBUG_ON)
    {
        NSLog(@"###################client dealloc()");
    }
    [self close];
}

- (void) close
{
    [self._lock lock];
    if (!self._isClosed)
    {
        if (self._sck_fd4!=SOCKET_NULL) {
            if (DEBUG_ON)
            {
                NSLog(@"###################client close() fd4=%d",self._sck_fd4);
            }
            close(self._sck_fd4);
            self._sck_fd4 = SOCKET_NULL;
        }
        if (self._sck_fd6!=SOCKET_NULL) {
            if (DEBUG_ON)
            {
                NSLog(@"###################client close() fd6=%d",self._sck_fd6);
            }
            close(self._sck_fd6);
            self._sck_fd6 = SOCKET_NULL;
        }
        self._isClosed = YES;
    }
    [self._lock unlock];
}

- (void) interrupt
{
    self._isStop = YES;
}

- (void) sendDataWithBytesArray2: (NSArray *) bytesArray2 ToTargetHostName: (NSString *)targetHostName WithPort: (int) port
                     andInterval: (long) interval
{
    return [self sendDataWithBytesArray2:bytesArray2 Offset:0 Count:[bytesArray2 count] ToTargetHostName:targetHostName WithPort:port andInterval:interval];
}

- (void) sendDataWithBytesArray2Ipv4: (NSArray *) bytesArray2 Offset: (NSUInteger) offset Count: (NSUInteger) count ToTargetHostName: (NSString *)targetHostName WithPort: (int) port
                     andInterval: (long) interval
{
    // LAB-3 runtime resolver: derive routing/broadcast from the active interface; preserve multicast targets.
    NSString *effectiveHost = targetHostName;
    BOOL labIsMulticast = [targetHostName hasPrefix:@"234."];
    struct ifaddrs *ifaddr = NULL;
    if (getifaddrs(&ifaddr) == 0) {
        for (struct ifaddrs *ifa = ifaddr; ifa; ifa = ifa->ifa_next) {
            if (!ifa->ifa_addr || ifa->ifa_addr->sa_family != AF_INET || !(ifa->ifa_flags & IFF_UP)) continue;
            NSString *name = [NSString stringWithUTF8String:ifa->ifa_name];
            // Runtime resolver: never assume bridge/en/pdp names or a fixed subnet.
            // Reject only loopback and interfaces without a usable non-host IPv4 netmask.
            if (ifa->ifa_flags & IFF_LOOPBACK) continue;
            if (!ifa->ifa_netmask) continue;
            struct sockaddr_in *sin = (struct sockaddr_in *)ifa->ifa_addr;
            struct sockaddr_in *mask = (struct sockaddr_in *)ifa->ifa_netmask;
            uint32_t ipHost = ntohl(sin->sin_addr.s_addr);
            uint32_t maskHost = mask ? ntohl(mask->sin_addr.s_addr) : 0xffffffff;
            uint32_t broadcastHost = ipHost | ~maskHost;
            struct in_addr baddr = { htonl(broadcastHost) };
            char buf[INET_ADDRSTRLEN] = {0};
            inet_ntop(AF_INET, &baddr, buf, sizeof(buf));
            if (!labIsMulticast) { effectiveHost = [NSString stringWithUTF8String:buf]; }
            unsigned int ifindex = if_nametoindex(ifa->ifa_name);
            int rc = setsockopt(self._sck_fd4, IPPROTO_IP, IP_BOUND_IF, &ifindex, sizeof(ifindex));
            NSLog(@"LAB3 ESPTouch V1 runtime candidate interface=%@ index=%u ip=%s broadcast=%@ IP_BOUND_IF rc=%d errno=%d",
                  name, ifindex, inet_ntoa(sin->sin_addr), effectiveHost, rc, errno);
            break;
        }
        freeifaddrs(ifaddr);
    }
    bool isBroadcast = !labIsMulticast;
    socklen_t addr_len;
    struct sockaddr_in target_addr;
    memset(&target_addr, 0, sizeof(target_addr));
    target_addr.sin_family = AF_INET;
    target_addr.sin_addr.s_addr = inet_addr([effectiveHost cStringUsingEncoding:NSASCIIStringEncoding]);
    target_addr.sin_port = htons(port);
    addr_len = sizeof(target_addr);
    if (isBroadcast) {
        const int opt = 1;
        // set whether the socket is broadcast or not
        if (setsockopt(self._sck_fd4,SOL_SOCKET,SO_BROADCAST,(char *)&opt, sizeof(opt)) < 0)
        {
            if (DEBUG_ON)
            {
                perror("client: setsockopt SO_BROADCAST fail, but just ignore it\n");
            }
            // for the Ap will make some troubles when the phone send too many UDP packets,
            // but we don't expect the UDP packet received by others, so just ignore it
        }
    }
    // send data gotten from the array
    for (NSUInteger i = offset; !self._isStop && i < offset + count; i++) {
        // get data
        NSData* data = [bytesArray2 objectAtIndex:i];
        NSUInteger dataLen = [data length];
        if (0 == dataLen)
        {
            continue;
        }
        Byte bytes[dataLen];
        [data getBytes:bytes length:dataLen];
        // send data
        ssize_t sent = sendto(self._sck_fd4, bytes, dataLen, 0, (struct sockaddr*)&target_addr, addr_len);
        if (sent < 0)
        {
            if (DEBUG_ON)
            {
                NSLog(@"LAB3 ESPTouch V1 sendto FAIL host=%@ port=%d len=%lu errno=%d", effectiveHost, port, (unsigned long)dataLen, errno);
            }
            // for the Ap will make some troubles when the phone send too many UDP packets,
            // but we don't expect the UDP packet received by others, so just ignore it
        }
        // sleep interval
        usleep((useconds_t)(interval*1000));
    }
    // check whether the client is stop
    if (self._isStop) {
        [self close];
    }
}

- (void) sendDataWithBytesArray2Ipv6: (NSArray *) bytesArray2 Offset: (NSUInteger) offset Count: (NSUInteger) count ToTargetHostName: (NSString *)targetHostName WithPort: (int) port
                         andInterval: (long) interval
{
    // init socket parameters
    socklen_t addr_len;
    struct sockaddr_in6 target_addr6;
    memset(&target_addr6, 0, sizeof(target_addr6));
    target_addr6.sin6_family = AF_INET6;
    target_addr6.sin6_port = htons(port);
    addr_len = sizeof(target_addr6);
    
    NSString *portStr = [NSString stringWithFormat:@"%hu",(uint16_t)port];
    struct addrinfo *res0,hints;
    memset(&hints, 0, sizeof(hints));
    hints.ai_family = AF_INET6;
    hints.ai_socktype = SOCK_DGRAM;
    hints.ai_protocol = IPPROTO_UDP;
    
    int gai_error = getaddrinfo([targetHostName UTF8String], [portStr UTF8String], &hints, &res0);
    if (gai_error) {
        perror("client: gai_error, stop");
        return;
    }
    NSData *dstData = [NSData dataWithBytes:res0->ai_addr length:res0->ai_addrlen];
    const void *dst = [dstData bytes];
    socklen_t dstSize = addr_len;
    
    // send data gotten from the array
    for (NSUInteger i = offset; !self._isStop && i < offset + count; i++) {
        // get data
        NSData* data = [bytesArray2 objectAtIndex:i];
        NSUInteger dataLen = [data length];
        if (0 == dataLen)
        {
            continue;
        }
        Byte bytes[dataLen];
        [data getBytes:bytes length:dataLen];
        // send data
        if (sendto(self._sck_fd6, bytes, dataLen, 0, dst, dstSize) < 0)
        {
            if (DEBUG_ON)
            {
                perror("client: sendto fail, but just ignore it\n");
            }
            // for the Ap will make some troubles when the phone send too many UDP packets,
            // but we don't expect the UDP packet received by others, so just ignore it
        }
        // sleep interval
        usleep((useconds_t)(interval*1000));
    }
    // check whether the client is stop
    if (self._isStop) {
        [self close];
    }
}

- (void) sendDataWithBytesArray2: (NSArray *) bytesArray2 Offset: (NSUInteger) offset Count: (NSUInteger) count ToTargetHostName: (NSString *)targetHostName WithPort: (int) port
                     andInterval: (long) interval
{
    // check data is valid
    if (nil == bytesArray2 || 0 == [bytesArray2 count])
    {
        if (DEBUG_ON)
        {
            perror("client: data is null or data's length equals 0, so sendData fail\n");
        }
        [self close];
        return;
    }
    if ([ESP_NetUtil isIPv4Addr:targetHostName]) {
        [self sendDataWithBytesArray2Ipv4:bytesArray2 Offset:offset Count:count ToTargetHostName:targetHostName WithPort:port andInterval:interval];
    } else {
        [self sendDataWithBytesArray2Ipv6:bytesArray2 Offset:offset Count:count ToTargetHostName:targetHostName WithPort:port andInterval:interval];
    }
}

@end

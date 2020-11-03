//
//  Copyright (c) 2019 Open Whisper Systems. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface PreKeyBundle : NSObject <NSSecureCoding>

@property (nonatomic, readonly) NSData   *identityKey;
@property (nonatomic, readonly) int      registrationId;
@property (nonatomic, readonly) int      deviceId;
@property (nonatomic, readonly) NSData   *signedPreKeyPublic;
@property (nonatomic, readonly) NSData   *preKeyPublic;
@property (nonatomic, readonly) int      preKeyId;
@property (nonatomic, readonly) int      signedPreKeyId;
@property (nonatomic, readonly) NSData   *signedPreKeySignature;

- (nullable instancetype)initWithRegistrationId:(int)registrationId
                                       deviceId:(int)deviceId
                                       preKeyId:(int)preKeyId
                                   preKeyPublic:(NSData *)preKeyPublic
                             signedPreKeyPublic:(NSData *)signedPreKeyPublic
                                 signedPreKeyId:(int)signedPreKeyId
                          signedPreKeySignature:(NSData *)signedPreKeySignature
                                    identityKey:(NSData *)identityKey;

@end

NS_ASSUME_NONNULL_END

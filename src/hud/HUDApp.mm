#import <cstddef>
#include <sys/_types/_pid_t.h>
#import <cstring>
#import <cstdlib>
#import <dlfcn.h>
#import <spawn.h>
#import <unistd.h>
#import <os/log.h>
#import <sys/param.h>
#import <sys/sysctl.h>
#import <mach-o/dyld.h>
#import <objc/runtime.h>


#pragma mark -

typedef struct __IOHIDEvent *IOHIDEventRef;
typedef struct __IOHIDNotification *IOHIDNotificationRef;
typedef struct __IOHIDService *IOHIDServiceRef;
typedef struct __GSEvent *GSEventRef;

#if __cplusplus
extern "C" {
#endif
void *BKSHIDEventRegisterEventCallback(void (*)(void *, void *, IOHIDServiceRef, IOHIDEventRef));
void UIApplicationInstantiateSingleton(id aclass);
void UIApplicationInitialize();
void BKSDisplayServicesStart();
void GSInitialize();
void GSEventInitialize(Boolean registerPurple);
void GSEventPopRunLoopMode(CFStringRef mode);
void GSEventPushRunLoopMode(CFStringRef mode);
void GSEventRegisterEventCallBack(void (*)(GSEventRef));
#if __cplusplus
}
#endif


#pragma mark -

@interface UIApplication (Private)
- (id)_systemAnimationFenceExemptQueue;
- (void)_accessibilityInit;
- (void)_enqueueHIDEvent:(IOHIDEventRef)event;
- (void)__completeAndRunAsPlugin;
@end

@interface UIEventFetcher : NSObject
- (void)_receiveHIDEvent:(IOHIDEventRef)arg1;
@end

@interface AXEventPathInfoRepresentation : NSObject
@property (assign, nonatomic) unsigned char pathIdentity;
@end

@interface AXEventHandInfoRepresentation : NSObject
- (NSArray <AXEventPathInfoRepresentation *> *)paths;
@end

@interface AXEventRepresentation : NSObject
@property (nonatomic, readonly) BOOL isTouchDown; 
@property (nonatomic, readonly) BOOL isMove; 
@property (nonatomic, readonly) BOOL isChordChange; 
@property (nonatomic, readonly) BOOL isLift; 
@property (nonatomic, readonly) BOOL isInRange; 
@property (nonatomic, readonly) BOOL isInRangeLift; 
@property (nonatomic, readonly) BOOL isCancel; 
+ (instancetype)representationWithHIDEvent:(IOHIDEventRef)event hidStreamIdentifier:(NSString *)identifier;
- (AXEventHandInfoRepresentation *)handInfo;
- (CGPoint)location;
@end


#pragma mark -

#import "../helpers/ts/TSEventFetcher.h"

static __used void _HUDEventCallback(void *target, void *refcon, IOHIDServiceRef service, IOHIDEventRef event)
{
    static UIApplication *app = [UIApplication sharedApplication];
    [app _enqueueHIDEvent:event];

    BOOL shouldUseAXEvent = NO;

    if (@available(iOS 15.2, *))
    {
        if (@available(iOS 16.2, *))
        {
            
        } else {
            shouldUseAXEvent = YES;
        }
    }

    if (shouldUseAXEvent) {
        static Class AXEventRepresentationCls = nil;
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{
            [[NSBundle bundleWithPath:@"/System/Library/PrivateFrameworks/AccessibilityUtilities.framework"] load];
            AXEventRepresentationCls = objc_getClass("AXEventRepresentation");
        });
        
        AXEventRepresentation *rep = [AXEventRepresentationCls representationWithHIDEvent:event hidStreamIdentifier:@"UIApplicationEvents"];
#if DEBUG
        os_log_debug(OS_LOG_DEFAULT, "_HUDEventCallback => %{public}@", rep.handInfo);
#endif

        /* I don't like this. It's too hacky, but it works. */
        {
            static UIWindow *keyWindow = nil;
            static dispatch_once_t onceToken;
            dispatch_once(&onceToken, ^{
                if ([NSThread isMainThread])
                    keyWindow = [[app windows] firstObject];
                else
                {
                    dispatch_sync(dispatch_get_main_queue(), ^{
                        keyWindow = [[app windows] firstObject];
                    });
                }
            });

            UIView *keyView = [keyWindow hitTest:[rep location] withEvent:nil];
            
            UITouchPhase phase = UITouchPhaseCancelled;
            if ([rep isTouchDown])
                phase = UITouchPhaseBegan;
            else if ([rep isMove])
                phase = UITouchPhaseMoved;
            else if ([rep isCancel])
                phase = UITouchPhaseCancelled;
            else if ([rep isLift] || [rep isInRange] || [rep isInRangeLift])
                phase = UITouchPhaseEnded;
            
            NSInteger pointerId = [[[[rep handInfo] paths] firstObject] pathIdentity];
            if (pointerId > 0)
                [TSEventFetcher receiveAXEventID:MIN(MAX(pointerId, 1), 98) atGlobalCoordinate:[rep location] withTouchPhase:phase inWindow:keyWindow onView:keyView];
        }
    }
    else {
#if DEBUG
        os_log_debug(OS_LOG_DEFAULT, "_HUDEventCallback => %{public}@", event);
#endif
    }
}


#pragma mark -

static NSString *_cachesDirectoryPath = nil;
static NSString *_hudPIDFilePath = nil;
static NSString *GetPIDFilePath(void)
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _cachesDirectoryPath = 
        [NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) firstObject];
        _hudPIDFilePath = [_cachesDirectoryPath stringByAppendingPathComponent:@"hud.pid"];
    });
    return _hudPIDFilePath;
}


#ifdef __cplusplus
extern "C" {
#endif
#import "../helpers/private_headers/libproc.h"
#import "../helpers/private_headers/kern_memorystatus.h"
#ifdef __cplusplus
}
#endif

__used
static inline
void BypassJetsamByProcess(pid_t me, BOOL critical) {
    int rc; memorystatus_priority_properties_t props = { JETSAM_PRIORITY_CRITICAL, 0 };
    rc = memorystatus_control(MEMORYSTATUS_CMD_SET_PRIORITY_PROPERTIES, me, 0, &props, sizeof(props));
    if (critical && rc < 0) { perror ("memorystatus_control"); exit(rc); }
    rc = memorystatus_control(MEMORYSTATUS_CMD_SET_JETSAM_HIGH_WATER_MARK, me, -1, NULL, 0);
    if (critical && rc < 0) { perror ("memorystatus_control"); exit(rc); }
    rc = memorystatus_control(MEMORYSTATUS_CMD_SET_JETSAM_TASK_LIMIT, me, 0x100, NULL, 0);
    if (critical && rc < 0) { perror ("memorystatus_control"); exit(rc); }
    rc = memorystatus_control(MEMORYSTATUS_CMD_SET_PROCESS_IS_MANAGED, me, 0, NULL, 0);
    if (critical && rc < 0) { perror ("memorystatus_control"); exit(rc); }
    rc = memorystatus_control(MEMORYSTATUS_CMD_SET_PROCESS_IS_FREEZABLE, me, 0, NULL, 0);
    if (critical && rc < 0) { perror ("memorystatus_control"); exit(rc); }
    rc = proc_track_dirty(me, 0);
    if (critical && rc != 0) { perror("proc_track_dirty"); exit(rc); }
    os_log_debug(OS_LOG_DEFAULT, "Oh, My Jetsam: %d", me);
}


#pragma mark -

int main(int argc, char *argv[])
{
    @autoreleasepool
    {
#if DEBUG
        os_log_debug(OS_LOG_DEFAULT, "launched argc %{public}d, argv[1] %{public}s", argc, argc > 1 ? argv[1] : "NULL");
#endif

        if (argc <= 1)
            return UIApplicationMain(argc, argv, @"MainApplication", @"MainApplicationDelegate");
        
        if (strcmp(argv[1], "-hud") == 0)
        {
            pid_t pid = getpid();
#if SPAWN_AS_ROOT
            BypassJetsamByProcess(pid, YES);
#endif
            NSString *pidString = [NSString stringWithFormat:@"%d", pid];
            [pidString writeToFile:GetPIDFilePath()
                        atomically:YES
                          encoding:NSUTF8StringEncoding
                             error:nil];
            
            [UIScreen initialize];
            CFRunLoopGetCurrent();

            GSInitialize();
            BKSDisplayServicesStart();
            UIApplicationInitialize();

            UIApplicationInstantiateSingleton(objc_getClass("HUDMainApplication"));
            static id<UIApplicationDelegate> appDelegate = [[objc_getClass("HUDMainApplicationDelegate") alloc] init];
            [UIApplication.sharedApplication setDelegate:appDelegate];
            [UIApplication.sharedApplication _accessibilityInit];

            [NSRunLoop currentRunLoop];
            BKSHIDEventRegisterEventCallback(_HUDEventCallback);

            if (@available(iOS 15.0, *)) {
                GSEventInitialize(0);
                GSEventPushRunLoopMode(kCFRunLoopDefaultMode);
            }
            
            [UIApplication.sharedApplication __completeAndRunAsPlugin];
            
            CFRunLoopRun();
            return EXIT_SUCCESS;
        }
        else if (strcmp(argv[1], "-exit") == 0)
        {
            NSString *pidString = [NSString stringWithContentsOfFile:GetPIDFilePath()
                                                            encoding:NSUTF8StringEncoding
                                                               error:nil];
            
            if (pidString)
            {
                pid_t pid = (pid_t)[pidString intValue];
                kill(pid, SIGKILL);
                unlink(GetPIDFilePath().UTF8String);
            }

            return EXIT_SUCCESS;
        }
        else if (strcmp(argv[1], "-check") == 0)
        {
            NSString *pidString = [NSString stringWithContentsOfFile:GetPIDFilePath()
                                                            encoding:NSUTF8StringEncoding
                                                               error:nil];
            
            if (pidString)
            {
                pid_t pid = (pid_t)[pidString intValue];
                int killed = kill(pid, 0);
                return (killed == 0 ? EXIT_FAILURE : EXIT_SUCCESS);
            }
            else return EXIT_SUCCESS;  // No PID file, so HUD is not running
        }
    }
}
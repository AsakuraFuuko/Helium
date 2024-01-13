//
//  HUDMainApplication.m
//  
//
//  Created by lemin on 10/5/23.
//

#import <cstddef>
#import <cstdlib>
#import <dlfcn.h>
#import <spawn.h>
#import <unistd.h>
#import <notify.h>
#import <net/if.h>
#import <ifaddrs.h>
#import <sys/wait.h>
#import <sys/types.h>
#import <sys/sysctl.h>
#import <mach-o/dyld.h>
#import <objc/runtime.h>
#include "../widgets/WidgetManager.h"
#include "../extensions/UsefulFunctions.h"
#include "../extensions/FontUtils.h"
#include "../helpers/private_headers/CAFilter.h"


extern "C" char **environ;

#define POSIX_SPAWN_PERSONA_FLAGS_OVERRIDE 1
extern "C" int posix_spawnattr_set_persona_np(const posix_spawnattr_t* __restrict, uid_t, uint32_t);
extern "C" int posix_spawnattr_set_persona_uid_np(const posix_spawnattr_t* __restrict, uid_t);
extern "C" int posix_spawnattr_set_persona_gid_np(const posix_spawnattr_t* __restrict, uid_t);


extern "C" BOOL IsHUDEnabled(void);
BOOL IsHUDEnabled(void)
{
    static char *executablePath = NULL;
    uint32_t executablePathSize = 0;
    _NSGetExecutablePath(NULL, &executablePathSize);
    executablePath = (char *)calloc(1, executablePathSize);
    _NSGetExecutablePath(executablePath, &executablePathSize);

    posix_spawnattr_t attr;
    posix_spawnattr_init(&attr);

    // posix_spawnattr_set_persona_np(&attr, 99, POSIX_SPAWN_PERSONA_FLAGS_OVERRIDE);
    // posix_spawnattr_set_persona_uid_np(&attr, 0);
    // posix_spawnattr_set_persona_gid_np(&attr, 0);

    pid_t task_pid;
    const char *args[] = { executablePath, "-check", NULL };
    posix_spawn(&task_pid, executablePath, NULL, &attr, (char **)args, environ);
    posix_spawnattr_destroy(&attr);

#if DEBUG
    os_log_debug(OS_LOG_DEFAULT, "spawned %{public}s -check pid = %{public}d", executablePath, task_pid);
#endif
    
    int status;
    do {
        if (waitpid(task_pid, &status, 0) != -1)
        {
#if DEBUG
            os_log_debug(OS_LOG_DEFAULT, "child status %d", WEXITSTATUS(status));
#endif
        }
    } while (!WIFEXITED(status) && !WIFSIGNALED(status));

    return WEXITSTATUS(status) != 0;
}

extern "C" void SetHUDEnabled(BOOL isEnabled);
void SetHUDEnabled(BOOL isEnabled)
{
#ifdef NOTIFY_DISMISSAL_HUD
    notify_post(NOTIFY_DISMISSAL_HUD);
#endif

    static char *executablePath = NULL;
    uint32_t executablePathSize = 0;
    _NSGetExecutablePath(NULL, &executablePathSize);
    executablePath = (char *)calloc(1, executablePathSize);
    _NSGetExecutablePath(executablePath, &executablePathSize);

    posix_spawnattr_t attr;
    posix_spawnattr_init(&attr);

    // posix_spawnattr_set_persona_np(&attr, 99, POSIX_SPAWN_PERSONA_FLAGS_OVERRIDE);
    // posix_spawnattr_set_persona_uid_np(&attr, 0);
    // posix_spawnattr_set_persona_gid_np(&attr, 0);

    if (isEnabled)
    {
        posix_spawnattr_setpgroup(&attr, 0);
        posix_spawnattr_setflags(&attr, POSIX_SPAWN_SETPGROUP);

        pid_t task_pid;
        const char *args[] = { executablePath, "-hud", NULL };
        posix_spawn(&task_pid, executablePath, NULL, &attr, (char **)args, environ);
        posix_spawnattr_destroy(&attr);

#if DEBUG
        os_log_debug(OS_LOG_DEFAULT, "spawned %{public}s -hud pid = %{public}d", executablePath, task_pid);
#endif
    }
    else
    {
        [NSThread sleepForTimeInterval:0.25];

        pid_t task_pid;
        const char *args[] = { executablePath, "-exit", NULL };
        posix_spawn(&task_pid, executablePath, NULL, &attr, (char **)args, environ);
        posix_spawnattr_destroy(&attr);

#if DEBUG
        os_log_debug(OS_LOG_DEFAULT, "spawned %{public}s -exit pid = %{public}d", executablePath, task_pid);
#endif
        
        int status;
        do {
            if (waitpid(task_pid, &status, 0) != -1)
            {
#if DEBUG
                os_log_debug(OS_LOG_DEFAULT, "child status %d", WEXITSTATUS(status));
#endif
            }
        } while (!WIFEXITED(status) && !WIFSIGNALED(status));
    }
}

extern "C" void waitForNotification(void (^onFinish)(), BOOL isEnabled);
void waitForNotification(void (^onFinish)(), BOOL isEnabled) {
    if (isEnabled)
   {
       dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);

       int token;
       notify_register_dispatch(NOTIFY_LAUNCHED_HUD, &token, dispatch_get_main_queue(), ^(int token) {
           notify_cancel(token);
           dispatch_semaphore_signal(semaphore);
       });

       dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
           int timedOut = dispatch_semaphore_wait(semaphore, dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5.0 * NSEC_PER_SEC)));
           dispatch_async(dispatch_get_main_queue(), ^{
               if (timedOut)
                   os_log_error(OS_LOG_DEFAULT, "Timed out waiting for HUD to launch");
               
               onFinish();
           });
       });
   }
   else
   {
       dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
           onFinish();
       });
   }
}


#pragma mark -

static double UPDATE_INTERVAL = 1.0;


#pragma mark -

@interface UIApplication (Private)
- (void)suspend;
- (void)terminateWithSuccess;
- (void)_run;
@end

@interface UIWindow (Private)
- (unsigned int)_contextId;
@end

@interface UIEventDispatcher : NSObject
- (void)_installEventRunLoopSources:(CFRunLoopRef)arg1;
@end

@interface UIEventFetcher : NSObject
- (void)setEventFetcherSink:(id)arg1;
- (void)displayLinkDidFire:(id)arg1;
@end

@interface _UIHIDEventSynchronizer : NSObject
- (void)_renderEvents:(id)arg1;
@end

@interface SBSAccessibilityWindowHostingController : NSObject
- (void)registerWindowWithContextID:(unsigned)arg1 atLevel:(double)arg2;
@end

@interface FBSOrientationObserver : NSObject
- (long long)activeInterfaceOrientation;
- (void)activeInterfaceOrientationWithCompletion:(id)arg1;
- (void)invalidate;
- (void)setHandler:(id)arg1;
- (id)handler;
@end

@interface FBSOrientationUpdate : NSObject
- (unsigned long long)sequenceNumber;
- (long long)rotationDirection;
- (long long)orientation;
- (double)duration;
@end


#pragma mark -

#import "../helpers/private_headers/UIAutoRotatingWindow.h"
#import "../helpers/private_headers/UIApplicationRotationFollowingControllerNoTouches.h"

@interface HUDMainApplicationDelegate : UIResponder <UIApplicationDelegate>
@property (nonatomic, strong) UIWindow *window;
@end

@interface HUDRootViewController: UIApplicationRotationFollowingControllerNoTouches
+ (BOOL)passthroughMode;
- (void)resetLoopTimer;
- (void)stopLoopTimer;
@end

@interface HUDMainWindow : UIAutoRotatingWindow
@end


#pragma mark - Darwin Notification

#define NOTIFY_UI_LOCKCOMPLETE "com.apple.springboard.lockcomplete"
#define NOTIFY_UI_LOCKSTATE    "com.apple.springboard.lockstate"
#define NOTIFY_LS_APP_CHANGED  "com.apple.LaunchServices.ApplicationsChanged"

#import "../helpers/private_headers/LSApplicationProxy.h"
#import "../helpers/private_headers/LSApplicationWorkspace.h"

static void LaunchServicesApplicationStateChanged
(CFNotificationCenterRef center,
 void *observer,
 CFStringRef name,
 const void *object,
 CFDictionaryRef userInfo)
{
    /* Application installed or uninstalled */

    BOOL isAppInstalled = NO;
    
    for (LSApplicationProxy *app in [[objc_getClass("LSApplicationWorkspace") defaultWorkspace] allApplications])
    {
        if ([app.applicationIdentifier isEqualToString:@"com.leemin.helium"])
        {
            isAppInstalled = YES;
            break;
        }
    }

    if (!isAppInstalled)
    {
        UIApplication *app = [UIApplication sharedApplication];
        [app terminateWithSuccess];
    }
}

#import "../helpers/private_headers/SpringBoardServices.h"

static void SpringBoardLockStatusChanged
(CFNotificationCenterRef center,
 void *observer,
 CFStringRef name,
 const void *object,
 CFDictionaryRef userInfo)
{
    HUDRootViewController *rootViewController = (__bridge HUDRootViewController *)observer;
    NSString *lockState = (__bridge NSString *)name;
    if ([lockState isEqualToString:@NOTIFY_UI_LOCKCOMPLETE])
    {
        [rootViewController stopLoopTimer];
        [rootViewController.view setHidden:YES];
    }
    else if ([lockState isEqualToString:@NOTIFY_UI_LOCKSTATE])
    {
        mach_port_t sbsPort = SBSSpringBoardServerPort();
        
        if (sbsPort == MACH_PORT_NULL)
            return;
        
        BOOL isLocked;
        BOOL isPasscodeSet;
        SBGetScreenLockStatus(sbsPort, &isLocked, &isPasscodeSet);

        if (!isLocked)
        {
            [rootViewController.view setHidden:NO];
            [rootViewController resetLoopTimer];
        }
        else
        {
            [rootViewController stopLoopTimer];
            [rootViewController.view setHidden:YES];
        }
    }
}


#pragma mark - HUDMainApplication

#import <pthread.h>
#import <mach/mach.h>

#import "../helpers/ts/pac_helper.h"

static void DumpThreads(void)
{
    char name[256];
    mach_msg_type_number_t count;
    thread_act_array_t list;
    task_threads(mach_task_self(), &list, &count);
    for (int i = 0; i < count; ++i)
    {
        pthread_t pt = pthread_from_mach_thread_np(list[i]);
        if (pt)
        {
            name[0] = '\0';
#if DEBUG
            int rc = pthread_getname_np(pt, name, sizeof name);
            os_log_debug(OS_LOG_DEFAULT, "mach thread %u: getname returned %d: %{public}s", list[i], rc, name);
#endif
        }
        else
        {
#if DEBUG
            os_log_debug(OS_LOG_DEFAULT, "mach thread %u: no pthread found", list[i]);
#endif
        }
    }
}

@interface HUDMainApplication : UIApplication
@end

@implementation HUDMainApplication

- (instancetype)init
{
    if (self = [super init])
    {
#if DEBUG
        os_log_debug(OS_LOG_DEFAULT, "- [HUDMainApplication init]");
#endif
        notify_post(NOTIFY_LAUNCHED_HUD);
        
#ifdef NOTIFY_DISMISSAL_HUD
        {
            int token;
            notify_register_dispatch(NOTIFY_DISMISSAL_HUD, &token, dispatch_get_main_queue(), ^(int token) {
                notify_cancel(token);
                
                // Fade out the HUD window
                [UIView animateWithDuration:0.25f animations:^{
                    [[self.windows firstObject] setAlpha:0.0];
                } completion:^(BOOL finished) {
                    // Terminate the HUD app
                    [self terminateWithSuccess];
                }];
            });
        }
#endif
        do {
            UIEventDispatcher *dispatcher = (UIEventDispatcher *)[self valueForKey:@"eventDispatcher"];
            if (!dispatcher)
            {
#if DEBUG
                os_log_error(OS_LOG_DEFAULT, "failed to get ivar _eventDispatcher");
#endif
                break;
            }

#if DEBUG
            os_log_debug(OS_LOG_DEFAULT, "got ivar _eventDispatcher: %p", dispatcher);
#endif

            if ([dispatcher respondsToSelector:@selector(_installEventRunLoopSources:)])
            {
                CFRunLoopRef mainRunLoop = CFRunLoopGetMain();
                [dispatcher _installEventRunLoopSources:mainRunLoop];
            }
            else
            {
                IMP runMethodIMP = class_getMethodImplementation([self class], @selector(_run));
                if (!runMethodIMP)
                {
#if DEBUG
                    os_log_error(OS_LOG_DEFAULT, "failed to get - [UIApplication _run] method");
#endif
                    break;
                }

                uint32_t *runMethodPtr = (uint32_t *)make_sym_readable((void *)runMethodIMP);
#if DEBUG
                os_log_debug(OS_LOG_DEFAULT, "- [UIApplication _run]: %p", runMethodPtr);
#endif

                void (*orig_UIEventDispatcher__installEventRunLoopSources_)(id _Nonnull, SEL _Nonnull, CFRunLoopRef) = NULL;
                for (int i = 0; i < 0x140; i++)
                {
                    // mov x2, x0
                    // mov x0, x?
                    if (runMethodPtr[i] != 0xaa0003e2 || (runMethodPtr[i + 1] & 0xff000000) != 0xaa000000)
                        continue;
                    
                    // bl -[UIEventDispatcher _installEventRunLoopSources:]
                    uint32_t blInst = runMethodPtr[i + 2];
                    uint32_t *blInstPtr = &runMethodPtr[i + 2];
                    if ((blInst & 0xfc000000) != 0x94000000)
                    {
#if DEBUG
                        os_log_error(OS_LOG_DEFAULT, "not a BL instruction: 0x%x, address %p", blInst, blInstPtr);
#endif
                        continue;
                    }

#if DEBUG
                    os_log_debug(OS_LOG_DEFAULT, "found BL instruction: 0x%x, address %p", blInst, blInstPtr);
#endif

                    int32_t blOffset = blInst & 0x03ffffff;
                    if (blOffset & 0x02000000)
                        blOffset |= 0xfc000000;
                    blOffset <<= 2;

#if DEBUG
                    os_log_debug(OS_LOG_DEFAULT, "BL offset: 0x%x", blOffset);
#endif

                    uint64_t blAddr = (uint64_t)blInstPtr + blOffset;

#if DEBUG
                    os_log_debug(OS_LOG_DEFAULT, "BL target address: %p", (void *)blAddr);
#endif
                    
                    // cbz x0, loc_?????????
                    uint32_t cbzInst = *((uint32_t *)make_sym_readable((void *)blAddr));
                    if ((cbzInst & 0xff000000) != 0xb4000000)
                    {
#if DEBUG
                        os_log_error(OS_LOG_DEFAULT, "not a CBZ instruction: 0x%x", cbzInst);
#endif
                        continue;
                    }

#if DEBUG
                    os_log_debug(OS_LOG_DEFAULT, "found CBZ instruction: 0x%x, address %p", cbzInst, (void *)blAddr);
#endif
                    
                    orig_UIEventDispatcher__installEventRunLoopSources_ = (void (*)(id  _Nonnull __strong, SEL _Nonnull, CFRunLoopRef))make_sym_callable((void *)blAddr);
                }

                if (!orig_UIEventDispatcher__installEventRunLoopSources_)
                {
#if DEBUG
                    os_log_error(OS_LOG_DEFAULT, "failed to find -[UIEventDispatcher _installEventRunLoopSources:]");
#endif
                    break;
                }

#if DEBUG
                os_log_debug(OS_LOG_DEFAULT, "- [UIEventDispatcher _installEventRunLoopSources:]: %p", orig_UIEventDispatcher__installEventRunLoopSources_);
#endif

                CFRunLoopRef mainRunLoop = CFRunLoopGetMain();
                orig_UIEventDispatcher__installEventRunLoopSources_(dispatcher, @selector(_installEventRunLoopSources:), mainRunLoop);
            }

#if DEBUG
            // Get image base with dyld, the image is /System/Library/PrivateFrameworks/UIKitCore.framework/UIKitCore.
            uint64_t imageUIKitCore = 0;
            {
                uint32_t imageCount = _dyld_image_count();
                for (uint32_t i = 0; i < imageCount; i++)
                {
                    const char *imageName = _dyld_get_image_name(i);
                    if (imageName && !strcmp(imageName, "/System/Library/PrivateFrameworks/UIKitCore.framework/UIKitCore"))
                    {
                        imageUIKitCore = _dyld_get_image_vmaddr_slide(i);
                        break;
                    }
                }
            }

            os_log_debug(OS_LOG_DEFAULT, "UIKitCore: %p", (void *)imageUIKitCore);
#endif

            UIEventFetcher *fetcher = [[objc_getClass("UIEventFetcher") alloc] init];
            [dispatcher setValue:fetcher forKey:@"eventFetcher"];

            if ([fetcher respondsToSelector:@selector(setEventFetcherSink:)])
                [fetcher setEventFetcherSink:dispatcher];
            else
            {
                /* Tested on iOS 15.1.1 and below */
                [fetcher setValue:dispatcher forKey:@"eventFetcherSink"];

                /* Print NSThread names */
                DumpThreads();

#if DEBUG
                /* Force HIDTransformer to print logs */
                [[NSUserDefaults standardUserDefaults] setObject:@YES forKey:@"LogTouch" inDomain:@"com.apple.UIKit"];
                [[NSUserDefaults standardUserDefaults] setObject:@YES forKey:@"LogGesture" inDomain:@"com.apple.UIKit"];
                [[NSUserDefaults standardUserDefaults] setObject:@YES forKey:@"LogEventDispatch" inDomain:@"com.apple.UIKit"];
                [[NSUserDefaults standardUserDefaults] setObject:@YES forKey:@"LogGestureEnvironment" inDomain:@"com.apple.UIKit"];
                [[NSUserDefaults standardUserDefaults] setObject:@YES forKey:@"LogGestureExclusion" inDomain:@"com.apple.UIKit"];
                [[NSUserDefaults standardUserDefaults] setObject:@YES forKey:@"LogSystemGestureUpdate" inDomain:@"com.apple.UIKit"];
                [[NSUserDefaults standardUserDefaults] setObject:@YES forKey:@"LogGesturePerformance" inDomain:@"com.apple.UIKit"];
                [[NSUserDefaults standardUserDefaults] setObject:@YES forKey:@"LogHIDTransformer" inDomain:@"com.apple.UIKit"];
                [[NSUserDefaults standardUserDefaults] synchronize];
#endif
            }

            [self setValue:fetcher forKey:@"eventFetcher"];
        } while (NO);
    }
    return self;
}

@end


#pragma mark - HUDMainApplicationDelegate

@implementation HUDMainApplicationDelegate {
    HUDRootViewController *_rootViewController;
    SBSAccessibilityWindowHostingController *_windowHostingController;
}

- (instancetype)init
{
    if (self = [super init])
    {
#if DEBUG
        os_log_debug(OS_LOG_DEFAULT, "- [HUDMainApplicationDelegate init]");
#endif
    }
    return self;
}

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary <UIApplicationLaunchOptionsKey, id> *)launchOptions
{
#if DEBUG
    os_log_debug(OS_LOG_DEFAULT, "- [HUDMainApplicationDelegate application:%{public}@ didFinishLaunchingWithOptions:%{public}@]", application, launchOptions);
#endif

    _rootViewController = [[HUDRootViewController alloc] init];

    self.window = [[HUDMainWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    [self.window setRootViewController:_rootViewController];
    
    [self.window setWindowLevel:10000010.0];
    [self.window setHidden:NO];
    [self.window makeKeyAndVisible];

    _windowHostingController = [[objc_getClass("SBSAccessibilityWindowHostingController") alloc] init];
    unsigned int _contextId = [self.window _contextId];
    double windowLevel = [self.window windowLevel];

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
    // [_windowHostingController registerWindowWithContextID:_contextId atLevel:windowLevel];
    NSMethodSignature *signature = [NSMethodSignature signatureWithObjCTypes:"v@:Id"];
    NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:signature];
    [invocation setTarget:_windowHostingController];
    [invocation setSelector:NSSelectorFromString(@"registerWindowWithContextID:atLevel:")];
    [invocation setArgument:&_contextId atIndex:2];
    [invocation setArgument:&windowLevel atIndex:3];
    [invocation invoke];
#pragma clang diagnostic pop

    return YES;
}

@end


#pragma mark - HUDMainWindow

@implementation HUDMainWindow

- (instancetype)initWithFrame:(CGRect)frame
{
    if (self = [super _initWithFrame:frame attached:NO])
    {
        self.backgroundColor = [UIColor clearColor];
        [self commonInit];
    }
    return self;
}

+ (BOOL)_isSystemWindow { return YES; }
- (BOOL)_isWindowServerHostingManaged { return NO; }
- (BOOL)_ignoresHitTest { return [HUDRootViewController passthroughMode]; }
// - (BOOL)keepContextInBackground { return YES; }
// - (BOOL)_usesWindowServerHitTesting { return NO; }
// - (BOOL)_isSecure { return YES; }
// - (BOOL)_wantsSceneAssociation { return NO; }
// - (BOOL)_alwaysGetsContexts { return YES; }
// - (BOOL)_shouldCreateContextAsSecure { return YES; }

@end


#pragma mark - AnyBackdropView

@interface AnyBackdropView : UIView
@end

@implementation AnyBackdropView
+ (Class)layerClass {
    return [NSClassFromString(@"CABackdropLayer") class];
}
@end

#pragma mark - HUDRootViewController

@implementation HUDRootViewController {
    NSMutableDictionary *_userDefaults;
    NSMutableArray <NSLayoutConstraint *> *_constraints;
    FBSOrientationObserver *_orientationObserver;
    // view object arrays
    NSMutableArray <AnyBackdropView *> *_backdropViews;
    NSMutableArray <UILabel *> *_maskLabelViews;

    NSMutableArray <UIVisualEffectView *> *_blurViews;
    NSMutableArray <UILabel *> *_labelViews;
    
    NSArray *testArr;
    
    UIView *_contentView;
    
    NSTimer *_timer;
    UIInterfaceOrientation _orientation;
}

- (void)registerNotifications
{
    int token;
    notify_register_dispatch(NOTIFY_RELOAD_HUD, &token, dispatch_get_main_queue(), ^(int token) {
        [self reloadUserDefaults];
    });

    CFNotificationCenterRef darwinCenter = CFNotificationCenterGetDarwinNotifyCenter();
    
    CFNotificationCenterAddObserver(
        darwinCenter,
        (__bridge const void *)self,
        LaunchServicesApplicationStateChanged,
        CFSTR(NOTIFY_LS_APP_CHANGED),
        NULL,
        CFNotificationSuspensionBehaviorDeliverImmediately
    );
    
    CFNotificationCenterAddObserver(
        darwinCenter,
        (__bridge const void *)self,
        SpringBoardLockStatusChanged,
        CFSTR(NOTIFY_UI_LOCKCOMPLETE),
        NULL,
        CFNotificationSuspensionBehaviorDeliverImmediately
    );
    
    CFNotificationCenterAddObserver(
        darwinCenter,
        (__bridge const void *)self,
        SpringBoardLockStatusChanged,
        CFSTR(NOTIFY_UI_LOCKSTATE),
        NULL,
        CFNotificationSuspensionBehaviorDeliverImmediately
    );
}

#pragma mark - User Default Stuff

#define USER_DEFAULTS_PATH @"/var/mobile/Library/Preferences/com.leemin.helium.plist"

- (void) loadUserDefaults:(BOOL)forceReload
{
    if (forceReload || !_userDefaults)
        _userDefaults = [[NSDictionary dictionaryWithContentsOfFile:USER_DEFAULTS_PATH] mutableCopy] ?: [NSMutableDictionary dictionary];
}

- (void) reloadUserDefaults
{
    [self loadUserDefaults: YES];

    double updateInterval = [self updateInterval];

    UPDATE_INTERVAL = updateInterval;
    
    [self updateViewConstraints];
}

+ (BOOL) passthroughMode
{
    return [[[NSDictionary dictionaryWithContentsOfFile:USER_DEFAULTS_PATH] objectForKey: @"passthroughMode"] boolValue];
}

- (BOOL) usesRotation
{
    [self loadUserDefaults:NO];
    NSNumber *mode = [_userDefaults objectForKey: @"usesRotation"];
    return mode ? [mode boolValue] : NO;
}

- (BOOL) ignoreSafeZone
{
    [self loadUserDefaults:NO];
    NSNumber *mode = [_userDefaults objectForKey: @"ignoreSafeZone"];
    return mode ? [mode boolValue] : NO;
}

- (double) updateInterval
{
    [self loadUserDefaults: NO];
    NSNumber *interval = [_userDefaults objectForKey: @"updateInterval"];
    if (interval ? [interval doubleValue] : 1.0 <= 0) {
        return 1.0;
    }
    return interval ? [interval doubleValue] : 1.0;
}
- (BOOL) adaptiveColors
{
    [self loadUserDefaults: NO];
    NSNumber *mode = [_userDefaults objectForKey: @"adaptiveColors"];
    return mode ? [mode boolValue] : NO;
}

/*
Example format for properties:
@[
    // EXAMPLE 1 \\
    @{
        // offset properties
        @"anchor" : @(0),               // 0 = left, 1 = center, 2 = right
        @"offsetX" : @(0),
        @"offsetY" : @(0),
        @"autoResizes" : @(NO),         // if yes, ignores scale property
        @"scale" : @(50),               // horizontal scale of label

        // widget properties
        @"widgetIDs" : @[
            @{
                @"widgetID" : @(2),
                @"isUp" : @(YES)
            },
            @{
                @"widgetID" : @(2)
            }
        ],

        // label properties
        @"blurDetails" : @{
            @"hasBlur" : @(YES),
            @"cornerRadius" : @(4)
        },
        @"colorDetails" : @{
            @"usesCustomColor" : @(YES),
            @"dynamicColor" : @(YES),   // if yes, different colors for dark/light mode
            @"lightColor" : @([UIColor blackColor]),
            @"darkColor" : @([UIColor whiteColor])
        },
        @"textBold" : @(NO),
        @"textItalic" : @(NO),
        @"textAlignment" : @(1),        // 0 = left, 1 = center, 2 = right, DEFAULT = 1
        @"fontSize" : @(10)
    },

    // EXAMPLE 2 \\
    @{
        // offset properties
        @"anchor" : @(1),               // 0 = left, 1 = center, 2 = right
        @"offsetX" : @(0),
        @"offsetY" : @(0),
        @"autoResizes" : @(YES),

        // widget properties
        @"widgetIDs" : @[
            @{
                @"widgetID" : @(6),
                @"text" : @"Cowabunga!"
            }
        ],

        // label properties
        @"blurDetails" : @{
            @"hasBlur" : @(YES),
            @"cornerRadius" : @(4)
        },
        @"colorDetails" : @{
            @"usesCustomColor" : @(YES),
            @"dynamicColor" : @(NO),
            @"color" : @([UIColor whiteColor])
        },
        @"textBold" : @(YES),
        @"textItalic" : @(YES),
        @"textAlignment" : @(0),        // 0 = left, 1 = center, 2 = right, DEFAULT = 1
        @"fontSize" : @(10)
    },

    // EXAMPLE 3: bare minimum \\
    @{
        // offset properties
        @"anchor" : @(1),               // 0 = left, 1 = center, 2 = right
        @"offsetX" : @(0),
        @"offsetY" : @(0),
        @"autoResizes" : @(YES),

        // widget properties
        @"widgetIDs" : @[
            @{
                @"widgetID" : @(5)
            }
        ],

        // label properties
        @"blurDetails" : @{
            @"hasBlur" : @(NO)
        },
        @"colorDetails" : @{
            @"usesCustomColor" : @(NO)
        },
    }
]
*/
- (NSArray*) widgetProperties
{
    [self loadUserDefaults: NO];
    NSArray *properties = [_userDefaults objectForKey: @"widgetProperties"];
    return properties;
}

#pragma mark - Label Updating

- (void) updateAllLabels
{
    // TODO: THIS NEEDS OPTIMIZATION (is updated frequently)
    NSArray *widgetProps = [self widgetProperties];
    for (int i = 0; i < [widgetProps count]; i++) {
        UILabel *labelView = [_labelViews objectAtIndex:i];
        NSDictionary *properties = [widgetProps objectAtIndex:i];
        if (!labelView || !properties)
            break;
        NSArray *identifiers = [properties objectForKey: @"widgetIDs"] ? [properties objectForKey: @"widgetIDs"] : @[];
        double fontSize = [properties objectForKey: @"fontSize"] ? [[properties objectForKey: @"fontSize"] doubleValue] : 10.0;
        BOOL textBold = [properties objectForKey: @"textBold"] ? [[properties objectForKey: @"textBold"] boolValue] : false;
        if ([self adaptiveColors]) {
            UILabel *maskLabelView = [_maskLabelViews objectAtIndex:i];
            AnyBackdropView *backdropView = [_backdropViews objectAtIndex:i];
            if (maskLabelView && backdropView) {
                [self updateLabel: labelView updateMaskLabel: maskLabelView backdropView: backdropView identifiers: identifiers fontSize: fontSize textBold: textBold];
                continue;
            }
        }
        // NSString *fontName = getStringFromDictKey(properties, @"fontName", "Default Font");
        // [self updateLabel: labelView identifiers: identifiers fontName: fontName fontSize: fontSize textBold: textBold];
        if ([identifiers count] > 0) {
            [[_blurViews objectAtIndex:i] setHidden: NO];
            [self updateLabel: labelView identifiers: identifiers fontSize: fontSize textBold: textBold];
        } else {
            [[_blurViews objectAtIndex:i] setHidden: YES];
        }
    }
}

- (void) updateLabel:(UILabel *) label updateMaskLabel:(UILabel *) maskLabel backdropView:(AnyBackdropView *) backdropView identifiers:(NSArray *) identifiers fontSize:(double) fontSize textBold:(bool) textBold
{
#if DEBUG
    os_log_debug(OS_LOG_DEFAULT, "updateLabel");
#endif
    NSAttributedString *attributedText = formattedAttributedString(identifiers, fontSize, textBold, label.textColor);
    if (attributedText) {
        [label setAttributedText: attributedText];
        if (maskLabel) {
            [maskLabel setAttributedText: attributedText];
            [maskLabel setFrame:backdropView.bounds];
        }
    }
}

- (void) updateLabel:(UILabel *) label identifiers:(NSArray *) identifiers fontSize:(double) fontSize textBold:(bool) textBold
{
#if DEBUG
    os_log_debug(OS_LOG_DEFAULT, "updateLabel");
#endif
    NSAttributedString *attributedText = formattedAttributedString(identifiers, fontSize, textBold, label.textColor);
    if (attributedText) {
        [label setAttributedText: attributedText];
    }
}

#pragma mark - Initialization and Deallocation

- (instancetype)init
{
    self = [super init];
    if (self) {
        // load fonts from app
        [FontUtils loadFontsFromFolder:[NSString stringWithFormat:@"%@%@", [[NSBundle mainBundle] resourcePath],  @"/fonts"]];
        // load fonts from documents
        [FontUtils loadFontsFromFolder:[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject]];
        
        _constraints = [NSMutableArray array];
        _blurViews = [NSMutableArray array];
        _labelViews = [NSMutableArray array];
        if ([self adaptiveColors]) {
            _backdropViews = [NSMutableArray array];
            _maskLabelViews = [NSMutableArray array];
        }
        _orientationObserver = [[objc_getClass("FBSOrientationObserver") alloc] init];
        __weak HUDRootViewController *weakSelf = self;
        [_orientationObserver setHandler:^(FBSOrientationUpdate *orientationUpdate) {
            HUDRootViewController *strongSelf = weakSelf;
            dispatch_async(dispatch_get_main_queue(), ^{
                [strongSelf updateOrientation:(UIInterfaceOrientation)orientationUpdate.orientation animateWithDuration:orientationUpdate.duration];
            });
        }];
        [self registerNotifications];
    }
    return self;
}

- (void)dealloc
{
    [_orientationObserver invalidate];
}

#pragma mark - HUD UI Main Functions

static inline CGFloat orientationAngle(UIInterfaceOrientation orientation)
{
    switch (orientation) {
        case UIInterfaceOrientationPortraitUpsideDown:
            return M_PI;
        case UIInterfaceOrientationLandscapeLeft:
            return -M_PI_2;
        case UIInterfaceOrientationLandscapeRight:
            return M_PI_2;
        default:
            return 0;
    }
}

static inline CGRect orientationBounds(UIInterfaceOrientation orientation, CGRect bounds)
{
    switch (orientation) {
        case UIInterfaceOrientationLandscapeLeft:
        case UIInterfaceOrientationLandscapeRight:
            return CGRectMake(0, 0, bounds.size.height, bounds.size.width);
        default:
            return bounds;
    }
}

- (void)updateOrientation:(UIInterfaceOrientation)orientation animateWithDuration:(NSTimeInterval)duration
{
    BOOL usesRotation = [self usesRotation];
    
    if (!usesRotation)
    {
        if (orientation == UIInterfaceOrientationPortrait)
        {
            [UIView animateWithDuration:duration animations:^{
                self->_contentView.alpha = 1.0;
            }];
        }
        else
        {
            [UIView animateWithDuration:duration animations:^{
                self->_contentView.alpha = 0.0;
            }];
        }
        return;
    }

    if (orientation == _orientation)
        return;
    _orientation = orientation;

    CGRect bounds = orientationBounds(orientation, [UIScreen mainScreen].bounds);
    [self.view setNeedsUpdateConstraints];
    [self.view setHidden:YES];
    [self.view setBounds:bounds];
    
    [UIView animateWithDuration:duration animations:^{
        [self.view setTransform:CGAffineTransformMakeRotation(orientationAngle(orientation))];
    } completion:^(BOOL finished) {
        [self.view setHidden:NO];
    }];
}

- (void) viewDidLoad
{
    [super viewDidLoad];
    /* Just put your HUD view here */

    BOOL adaptive = [self adaptiveColors];
    
    // MARK: Main Content View
    _contentView = [[UIView alloc] init];
    _contentView.backgroundColor = [UIColor clearColor];
    _contentView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:_contentView];

    // MARK: Create the Widgets
    // MIGHT NEED OPTIMIZATION
    for (id propID in [self widgetProperties]) {
        NSDictionary *properties = propID;
        // create the blur
        NSDictionary *blurDetails = [properties valueForKey:@"blurDetails"] ? [properties valueForKey:@"blurDetails"] : @{@"hasBlur" : @(NO)};
        UIVisualEffectView *blurView = [[UIVisualEffectView alloc] initWithEffect:[
            UIBlurEffect effectWithStyle: getBoolFromDictKey(blurDetails, @"styleDark", true) ? UIBlurEffectStyleSystemMaterialDark : UIBlurEffectStyleSystemMaterialLight
        ]];
        blurView.layer.cornerRadius = getIntFromDictKey(blurDetails, @"cornerRadius", 4);
        blurView.layer.masksToBounds = YES;
        blurView.translatesAutoresizingMaskIntoConstraints = NO;
        BOOL hasBlur = getBoolFromDictKey(blurDetails, @"hasBlur");
        if (!hasBlur) {
            blurView.alpha = 0.0;
        } else {
            blurView.alpha = getDoubleFromDictKey(blurDetails, @"alpha", 1.0);
        }
        [_contentView addSubview:blurView];
        [_blurViews addObject:blurView];
        // create the label
        UILabel *labelView = [[UILabel alloc] initWithFrame: CGRectZero];
        labelView.numberOfLines = 0;
        NSInteger alignment = getIntFromDictKey(properties, @"textAlignment", 1);
        // alignment is different from anchor
        if (alignment == 0) {
            // align left
            labelView.textAlignment = NSTextAlignmentLeft;
        } else if (alignment == 1) {
            // align center
            labelView.textAlignment = NSTextAlignmentCenter;
        } else {
            // align right
            labelView.textAlignment = NSTextAlignmentRight;
        }
        // TODO: make functional
        /*NSDictionary *colorDetails = [properties valueForKey:@"colorDetails"] ? [properties valueForKey:@"colorDetails"] : [NSDictionary init];
        if (getBoolFromDictKey(colorDetails, @"usesCustomColor")) {
            // custom color
            UIColor color;
            if (getBoolFromDictKey(colorDetails, @"dynamicColor")) {
                color = []
            }
        }*/
        NSDictionary *colorDetails = [properties valueForKey:@"colorDetails"] ? [properties valueForKey:@"colorDetails"] : @{@"usesCustomColor" : @(NO)};
        BOOL usesCustomColor = getBoolFromDictKey(colorDetails, @"usesCustomColor");
        if (usesCustomColor && [colorDetails valueForKey:@"color"]) {
            NSData *customColorData = [colorDetails valueForKey:@"color"];
            UIColor *customColor = [NSKeyedUnarchiver unarchiveObjectWithData:customColorData];
            labelView.textColor = customColor;
        } else {
            labelView.textColor = [UIColor whiteColor];
        }
        // if (getBoolFromDictKey(properties, @"textBold")) {
        //     labelView.font = [UIFont boldSystemFontOfSize: getDoubleFromDictKey(properties, @"fontSize", 10)];
        // } else {
        //     labelView.font = [UIFont systemFontOfSize: getDoubleFromDictKey(properties, @"fontSize", 10)];
        // }
        NSString *fontName = getStringFromDictKey(properties, @"fontName", @"Default Font");
        UIFont *textFont = [FontUtils loadFontWithName:fontName size: getDoubleFromDictKey(properties, @"fontSize", 10) bold: getBoolFromDictKey(properties, @"textBold") italic: getBoolFromDictKey(properties, @"textItalic")];
        labelView.alpha = getIntFromDictKey(properties, @"textAlpha", 1.0);
        labelView.font = textFont;
        labelView.translatesAutoresizingMaskIntoConstraints = NO;
        if (adaptive && getBoolFromDictKey(colorDetails, @"dynamicColor", true)) {
            [labelView setContentHuggingPriority:UILayoutPriorityDefaultHigh forAxis:UILayoutConstraintAxisVertical];
            blurView.hidden = YES;
        }
        [_contentView addSubview: labelView];
        [_labelViews addObject: labelView];

        // MARK: Adaptive Color Backdrop
        // create adaptive label
        if (adaptive) {
            AnyBackdropView *backdropView = [[AnyBackdropView alloc] init];
            backdropView.translatesAutoresizingMaskIntoConstraints = NO;
            [_backdropViews addObject: backdropView];

            UILabel *maskLabel = [[UILabel alloc] initWithFrame:CGRectZero];
            maskLabel.numberOfLines = 0;
            maskLabel.lineBreakMode = NSLineBreakByClipping;
            maskLabel.textAlignment = alignment;
            maskLabel.textColor = [UIColor whiteColor];
            maskLabel.font = textFont;
            maskLabel.translatesAutoresizingMaskIntoConstraints = NO;
            if (getBoolFromDictKey(colorDetails, @"dynamicColor", true)) {
                CAFilter *blurFilter = [CAFilter filterWithName:kCAFilterGaussianBlur];
                CAFilter *brightnessFilter = [CAFilter filterWithName:kCAFilterColorBrightness];
                CAFilter *contrastFilter = [CAFilter filterWithName:kCAFilterColorContrast];
                CAFilter *saturateFilter = [CAFilter filterWithName:kCAFilterColorSaturate];
                CAFilter *colorInvertFilter = [CAFilter filterWithName:kCAFilterColorInvert];
                [blurFilter setValue:@(10.0) forKey:@"inputRadius"];
                [blurFilter setValue:@(YES) forKey:@"inputHardEdges"];
                [brightnessFilter setValue:@(0.06) forKey:@"inputAmount"];
                [contrastFilter setValue:@(10.0) forKey:@"inputAmount"];
                [saturateFilter setValue:@(0.0) forKey:@"inputAmount"];
                [backdropView.layer setFilters:@[
                    blurFilter, brightnessFilter, contrastFilter,
                    saturateFilter, colorInvertFilter,
                ]];
                [_contentView addSubview:backdropView];
                [maskLabel setContentHuggingPriority:UILayoutPriorityDefaultHigh forAxis:UILayoutConstraintAxisVertical];
                [backdropView setMaskView:maskLabel];
                labelView.alpha = 0;
                labelView.lineBreakMode = NSLineBreakByClipping;
            }
            [_maskLabelViews addObject: maskLabel];
        }
    }
    
    [self reloadUserDefaults];
    
    [self resetLoopTimer];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    if ([self adaptiveColors]) {
        for (int i = 0; i < [_maskLabelViews count]; i++) {
            UILabel *maskLabel = [_maskLabelViews objectAtIndex: i];
            AnyBackdropView *backdropView = [_backdropViews objectAtIndex: i];
            if (maskLabel && backdropView) {
                [maskLabel setFrame: backdropView.bounds];
            }
        }
    }
}

#pragma mark - Timer and View Updating

- (void)resetLoopTimer
{
    [_timer invalidate];
    _timer = [NSTimer scheduledTimerWithTimeInterval:UPDATE_INTERVAL target:self selector:@selector(updateAllLabels) userInfo:nil repeats:YES];
}

- (void)stopLoopTimer
{
    [_timer invalidate];
    _timer = nil;
}

- (void)viewSafeAreaInsetsDidChange
{
    [super viewSafeAreaInsetsDidChange];
    if (![self ignoreSafeZone]) {
        [self updateViewConstraints];
    }
}

- (void)updateViewConstraints
{
    [NSLayoutConstraint deactivateConstraints:_constraints];
    [_constraints removeAllObjects];

    BOOL isPad = ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad);
    UILayoutGuide *layoutGuide = self.view.safeAreaLayoutGuide;
    BOOL ignoreSZ = [self ignoreSafeZone];
    
    if (_orientation == UIInterfaceOrientationLandscapeLeft || _orientation == UIInterfaceOrientationLandscapeRight)
    {
        [_constraints addObjectsFromArray:@[
            [_contentView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:(!ignoreSZ && layoutGuide.layoutFrame.origin.y > 1) ? 20 : 4],
            [_contentView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:(!ignoreSZ && layoutGuide.layoutFrame.origin.y > 1) ? -20 : -4],
        ]];

        [_constraints addObjectsFromArray:@[
            [_contentView.topAnchor constraintEqualToAnchor:self.view.topAnchor constant:(isPad ? 30 : 10)],
            [_contentView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
        ]];
    }
    else
    {
        [_constraints addObjectsFromArray:@[
            [_contentView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
            [_contentView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        ]];
        
        if (!ignoreSZ && layoutGuide.layoutFrame.origin.y > 1)
            [_constraints addObject:[_contentView.topAnchor constraintEqualToAnchor:layoutGuide.topAnchor constant:-10]];
        else
            [_constraints addObject:[_contentView.topAnchor constraintEqualToAnchor:layoutGuide.topAnchor constant:(isPad ? 30 : 20)]];

        [_constraints addObject:[_contentView.bottomAnchor constraintEqualToAnchor:layoutGuide.bottomAnchor]];
    }

    // MARK: Set Label Constraints
    NSArray *widgetProps = [self widgetProperties];
    // DEFINITELY NEEDS OPTIMIZATION
    for (int i = 0; i < [widgetProps count]; i++) {
        UIVisualEffectView *blurView = [_blurViews objectAtIndex:i];
        UILabel *labelView = [_labelViews objectAtIndex:i];
        NSDictionary *properties = [widgetProps objectAtIndex:i];
        if (!blurView || !labelView || !properties)
            break;
        double offsetX = getDoubleFromDictKey(properties, @"offsetX", 10);
        double offsetY = getDoubleFromDictKey(properties, @"offsetY");
        NSInteger anchorSide = getIntFromDictKey(properties, @"anchor");
        NSInteger anchorYSide = getIntFromDictKey(properties, @"anchorY");
        // set the vertical anchor
        if (anchorYSide == 1)
            [_constraints addObject:[labelView.centerYAnchor constraintEqualToAnchor:_contentView.centerYAnchor constant: offsetY]];
        else if (anchorYSide == 0)
            [_constraints addObject:[labelView.topAnchor constraintEqualToAnchor:_contentView.topAnchor constant: offsetY]];
        else
            [_constraints addObject:[labelView.bottomAnchor constraintEqualToAnchor:_contentView.bottomAnchor constant: offsetY]];
        // set the horizontal anchor
        if (anchorSide == 1)
            [_constraints addObject:[labelView.centerXAnchor constraintEqualToAnchor:_contentView.centerXAnchor constant: offsetX]];
        else if (anchorSide == 0)
            [_constraints addObject:[labelView.leadingAnchor constraintEqualToAnchor:_contentView.leadingAnchor constant: offsetX]];
        else
            [_constraints addObject:[labelView.trailingAnchor constraintEqualToAnchor:_contentView.trailingAnchor constant: -offsetX]];
        // set the width
        if (!getBoolFromDictKey(properties, @"autoResizes")) {
            [_constraints addObject:[labelView.widthAnchor constraintEqualToConstant:getDoubleFromDictKey(properties, @"scale", 50.0)]];
            [_constraints addObject:[labelView.heightAnchor constraintEqualToConstant:getDoubleFromDictKey(properties, @"scaleY", 12.0)]];
        }

        if ([self adaptiveColors]) {
            NSDictionary *colorDetails = [properties valueForKey:@"colorDetails"] ? [properties valueForKey:@"colorDetails"] : @{@"dynamicColor" : @(YES)};
            if (getBoolFromDictKey(colorDetails, @"dynamicColor", true)) {
                AnyBackdropView *backdropView = [_backdropViews objectAtIndex: i];
                if (backdropView) {
                    [_constraints addObjectsFromArray:@[
                        [blurView.topAnchor constraintEqualToAnchor:backdropView.topAnchor],
                        [blurView.leadingAnchor constraintEqualToAnchor:backdropView.leadingAnchor],
                        [blurView.trailingAnchor constraintEqualToAnchor:backdropView.trailingAnchor],
                        [blurView.bottomAnchor constraintEqualToAnchor:backdropView.bottomAnchor],
                    ]];
                }
            }
        }
        
        [_constraints addObjectsFromArray:@[
            [blurView.topAnchor constraintEqualToAnchor:labelView.topAnchor constant:-2],
            [blurView.leadingAnchor constraintEqualToAnchor:labelView.leadingAnchor constant:-4],
            [blurView.trailingAnchor constraintEqualToAnchor:labelView.trailingAnchor constant:4],
            [blurView.bottomAnchor constraintEqualToAnchor:labelView.bottomAnchor constant:2],
        ]];
    }
    
    [NSLayoutConstraint activateConstraints:_constraints];
    [super updateViewConstraints];
}

@end

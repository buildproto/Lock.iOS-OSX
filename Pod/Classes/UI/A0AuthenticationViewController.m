//  A0AuthenticationViewController.m
//
// Copyright (c) 2014 Auth0 (http://auth0.com)
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.

#import "A0AuthenticationViewController.h"
#import "A0KeyboardHandler.h"
#import "A0Application.h"
#import "A0APIClient.h"
#import "A0SocialAuthenticator.h"
#import "A0DatabaseLoginCredentialValidator.h"
#import "A0SignUpCredentialValidator.h"

#import "A0LoadingViewController.h"
#import "A0DatabaseLoginViewController.h"
#import "A0SignUpViewController.h"

#import <CoreText/CoreText.h>
#import <libextobjc/EXTScope.h>

@interface A0AuthenticationViewController ()

@property (weak, nonatomic) IBOutlet UILabel *titleLabel;
@property (weak, nonatomic) IBOutlet UIView *containerView;

@property (strong, nonatomic) UIViewController<A0KeyboardEnabledView> *current;
@property (strong, nonatomic) A0KeyboardHandler *keyboardHandler;
@property (strong, nonatomic) A0Application *application;

- (IBAction)dismiss:(id)sender;

@end

@implementation A0AuthenticationViewController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
            self.modalPresentationStyle = UIModalPresentationFormSheet;
        }
        _usesEmail = YES;
        [A0AuthenticationViewController loadIconFont];
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];

    self.keyboardHandler = [[A0KeyboardHandler alloc] init];

    self.current = [self layoutController:[[A0LoadingViewController alloc] init] inContainer:self.containerView];

    @weakify(self);
    [[A0APIClient sharedClient] fetchAppInfoWithSuccess:^(A0Application *application) {
        @strongify(self);
        self.application = application;
        [[A0APIClient sharedClient] configureForApplication:application];
        [[A0SocialAuthenticator sharedInstance] configureForApplication:application];
        [self layoutRootControllerForApplication:application];
    } failure:nil];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self.keyboardHandler start];
}

- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
    [self.keyboardHandler stop];
}

- (BOOL)shouldAutorotate {
    return NO;
}

- (void)dismiss:(id)sender {
    [self.presentingViewController dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark - Container methods

- (void)layoutRootControllerForApplication:(A0Application *)application {
    @weakify(self);
    void(^onAuthSuccessBlock)(A0UserProfile *) =  ^(A0UserProfile *profile) {
        @strongify(self);
        [self.presentingViewController dismissViewControllerAnimated:YES completion:^{
            if (self.authBlock) {
                self.authBlock(self, profile);
            }
        }];
    };
    if ([application hasDatabaseConnection] && [application hasSocialStrategies]) {
        //FULL
    } else if ([application hasDatabaseConnection]) {
        A0DatabaseLoginViewController *controller = [[A0DatabaseLoginViewController alloc] init];
        controller.onLoginBlock = onAuthSuccessBlock;
        controller.onShowSignUp = ^ {
            @strongify(self);
            A0SignUpViewController *controller = [[A0SignUpViewController alloc] init];
            controller.validator = [[A0SignUpCredentialValidator alloc] initWithUsesEmail:self.usesEmail];
            @weakify(self);
            controller.onCancelBlock = ^{
                @strongify(self);
                [self layoutRootControllerForApplication:self.application];
            };
            controller.onSignUpBlock = onAuthSuccessBlock;
            self.current = [self layoutController:controller inContainer:self.containerView];
        };
        controller.validator = [[A0DatabaseLoginCredentialValidator alloc] initWithUsesEmail:self.usesEmail];
        self.current = [self layoutController:controller inContainer:self.containerView];
    } else if ([application hasSocialStrategies]) {
        //SOCIAL
    }
}

- (UIViewController<A0KeyboardEnabledView> *)layoutController:(UIViewController<A0KeyboardEnabledView> *)controller inContainer:(UIView *)containerView {
    controller.view.translatesAutoresizingMaskIntoConstraints = NO;
    [self.keyboardHandler handleForView:controller inView:self.view];
    [self.current willMoveToParentViewController:nil];
    [self addChildViewController:controller];
    [self layoutAuthView:controller.view centeredInContainerView:containerView];
    [self animateFromViewController:self.current toViewController:controller];
    return controller;
}

- (void)layoutAuthView:(UIView *)authView centeredInContainerView:(UIView *)containerView {
    containerView.translatesAutoresizingMaskIntoConstraints = NO;
    [containerView addSubview:authView];
    [containerView addConstraint:[NSLayoutConstraint constraintWithItem:containerView
                                                              attribute:NSLayoutAttributeCenterX
                                                              relatedBy:NSLayoutRelationEqual
                                                                 toItem:authView
                                                              attribute:NSLayoutAttributeCenterX
                                                             multiplier:1.0f
                                                               constant:0.0f]];
    [containerView addConstraint:[NSLayoutConstraint constraintWithItem:containerView
                                                              attribute:NSLayoutAttributeCenterY
                                                              relatedBy:NSLayoutRelationEqual
                                                                 toItem:authView
                                                              attribute:NSLayoutAttributeCenterY
                                                             multiplier:1.0f
                                                               constant:0.0f]];
    NSDictionary *views = NSDictionaryOfVariableBindings(authView);
    [containerView addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|[authView]|" options:0 metrics:nil views:views]];
}

- (void)animateFromViewController:(UIViewController *)from toViewController:(UIViewController *)to {
    from.view.alpha = 1.0f;
    to.view.alpha = 0.0f;
    [UIView animateWithDuration:0.5f animations:^{
        to.view.alpha = 1.0f;
        from.view.alpha = 0.0f;
        self.titleLabel.text = to.title;
    } completion:^(BOOL finished) {
        [from.view removeFromSuperview];
        [from removeFromParentViewController];
        [to didMoveToParentViewController:self];
    }];
}

#pragma mark - Icon Font loading

+ (void)loadIconFont {
    UIFont *iconFont = [UIFont fontWithName:@"connections" size:14.0f];
    if (!iconFont) {
        NSString *resourceBundlePath = [[NSBundle mainBundle] pathForResource:@"Auth0" ofType:@"bundle"];
        NSBundle *resourceBundle = [NSBundle bundleWithPath:resourceBundlePath];
        NSString *fontPath = [resourceBundle pathForResource:@"connections" ofType:@"ttf"];
        CFErrorRef error;
        CGDataProviderRef provider = CGDataProviderCreateWithFilename([fontPath UTF8String]);
        CGFontRef font = CGFontCreateWithDataProvider(provider);
        if (! CTFontManagerRegisterGraphicsFont(font, &error)) {
            CFStringRef errorDescription = CFErrorCopyDescription(error);
            NSLog(@"Failed to load font: %@", errorDescription);
            CFRelease(errorDescription);
            CFRelease(error);
        }
        CFRelease(font);
        CFRelease(provider);
    }
}

@end
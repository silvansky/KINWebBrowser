//
//  KINWebBrowserViewController.m
//
//  KINWebBrowser
//
//  Created by David F. Muir V
//  dfmuir@gmail.com
//  Co-Founder & Engineer at Kinwa, Inc.
//  http://www.kinwa.co
//
//  The MIT License (MIT)
//
//  Copyright (c) 2014 David Muir
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy of
//  this software and associated documentation files (the "Software"), to deal in
//  the Software without restriction, including without limitation the rights to
//  use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of
//  the Software, and to permit persons to whom the Software is furnished to do so,
//  subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in all
//  copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
//  FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
//  COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
//  IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
//  CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
//

#import "KINWebBrowserViewController.h"

#import <TUSafariActivity/TUSafariActivity.h>
#import <ARChromeActivity/ARChromeActivity.h>

static void *KINContext = &KINContext;

@interface KINWebBrowserViewController ()

@property (nonatomic, assign) BOOL previousNavigationControllerToolbarHidden, previousNavigationControllerNavigationBarHidden;
@property (nonatomic, strong) UIBarButtonItem *backButton, *forwardButton, *refreshButton, *stopButton, *actionButton, *fixedSeparator, *flexibleSeparator;
@property (nonatomic, strong) NSTimer *fakeProgressTimer;
@property (nonatomic, strong) UIPopoverController *actionPopoverController;
@property (nonatomic, assign) BOOL uiWebViewIsLoading;
@property (nonatomic, strong) NSURL *uiWebViewCurrentURL;
@property (nonatomic, strong) NSURL *wkWebViewCurrentURL;
@property (strong, nonatomic) NSMutableDictionary *HTTPHeaders;

@end

@implementation KINWebBrowserViewController

#pragma mark - Static Initializers

+ (KINWebBrowserViewController *)webBrowser {
    KINWebBrowserViewController *webBrowserViewController = [KINWebBrowserViewController webBrowserWithConfiguration:nil];
    return webBrowserViewController;
}

+ (KINWebBrowserViewController *)webBrowserWithConfiguration:(WKWebViewConfiguration *)configuration {
    KINWebBrowserViewController *webBrowserViewController = [[KINWebBrowserViewController alloc] initWithConfiguration:configuration];
    return webBrowserViewController;
}

+ (UINavigationController *)navigationControllerWithWebBrowser {
    KINWebBrowserViewController *webBrowserViewController = [[KINWebBrowserViewController alloc] initWithConfiguration:nil];
    return [KINWebBrowserViewController navigationControllerWithBrowser:webBrowserViewController];
}

+ (UINavigationController *)navigationControllerWithWebBrowserWithConfiguration:(WKWebViewConfiguration *)configuration {
    KINWebBrowserViewController *webBrowserViewController = [[KINWebBrowserViewController alloc] initWithConfiguration:configuration];
    return [KINWebBrowserViewController navigationControllerWithBrowser:webBrowserViewController];
}

+ (UINavigationController *)navigationControllerWithBrowser:(KINWebBrowserViewController *)webBrowser {
    UIBarButtonItem *doneButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:webBrowser action:@selector(doneButtonPressed:)];
    [webBrowser.navigationItem setRightBarButtonItem:doneButton];
    
    UINavigationController *navigationController = [[UINavigationController alloc] initWithRootViewController:webBrowser];
    return navigationController;
}

#pragma mark - Initializers

- (id)init {
    return [self initWithConfiguration:nil];
}

- (id)initWithConfiguration:(WKWebViewConfiguration *)configuration {
    self = [super init];
    if(self) {
        
        if(NO) {
            if(configuration) {
                self.wkWebView = [[WKWebView alloc] initWithFrame:CGRectZero configuration:configuration];
            }
            else {
                self.wkWebView = [[WKWebView alloc] init];
            }
        }
        else {
            self.uiWebView = [[UIWebView alloc] init];
        }
        
        self.actionButtonHidden = NO;
        self.showsURLInNavigationBar = NO;
        self.showsPageTitleInNavigationBar = YES;

		_HTTPHeaders = [NSMutableDictionary new];
    }
    return self;
}

#pragma mark - View Lifecycle

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.previousNavigationControllerToolbarHidden = self.navigationController.toolbarHidden;
    self.previousNavigationControllerNavigationBarHidden = self.navigationController.navigationBarHidden;
    
    if(self.wkWebView) {
        [self.wkWebView setFrame:self.view.bounds];
        [self.wkWebView setAutoresizingMask:UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight];
        [self.wkWebView setNavigationDelegate:self];
        [self.wkWebView setUIDelegate:self];
        [self.wkWebView setMultipleTouchEnabled:YES];
        [self.wkWebView setAutoresizesSubviews:YES];
        [self.wkWebView.scrollView setAlwaysBounceVertical:YES];
        [self.view addSubview:self.wkWebView];
        
        [self.wkWebView addObserver:self forKeyPath:NSStringFromSelector(@selector(estimatedProgress)) options:0 context:KINContext];
    }
    else if(self.uiWebView) {
        [self.uiWebView setFrame:self.view.bounds];
        [self.uiWebView setAutoresizingMask:UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight];
        [self.uiWebView setDelegate:self];
        [self.uiWebView setMultipleTouchEnabled:YES];
        [self.uiWebView setAutoresizesSubviews:YES];
        [self.uiWebView setScalesPageToFit:YES];
        [self.uiWebView.scrollView setAlwaysBounceVertical:YES];
        [self.view addSubview:self.uiWebView];
    }
    
    
    self.progressView = [[UIProgressView alloc] initWithProgressViewStyle:UIProgressViewStyleDefault];
    [self.progressView setTrackTintColor:[UIColor colorWithWhite:1.0f alpha:0.0f]];
    [self.progressView setFrame:CGRectMake(0, self.navigationController.navigationBar.frame.size.height-self.progressView.frame.size.height, self.view.frame.size.width, self.progressView.frame.size.height)];
    [self.progressView setAutoresizingMask:UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    [self.navigationController setNavigationBarHidden:NO animated:YES];
    [self.navigationController setToolbarHidden:NO animated:YES];
    
    [self.navigationController.navigationBar addSubview:self.progressView];
    
    [self updateToolbarState];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    
    [self.navigationController setNavigationBarHidden:self.previousNavigationControllerNavigationBarHidden animated:animated];
    
    [self.navigationController setToolbarHidden:self.previousNavigationControllerToolbarHidden animated:animated];
    
    [self.uiWebView setDelegate:nil];
    [self.progressView removeFromSuperview];
}

#pragma mark - Public Interface

- (void)loadURL:(NSURL *)URL {
	__weak KINWebBrowserViewController *wself = self;
	NSMutableURLRequest *request = [[NSMutableURLRequest alloc] initWithURL:URL];
	if (wself.headersFilter) {
		request.allHTTPHeaderFields = wself.headersFilter(URL, [wself.HTTPHeaders copy]);
	} else {
		request.allHTTPHeaderFields = wself.HTTPHeaders;
	}
    if(self.wkWebView) {
        [self.wkWebView loadRequest:request];
    }
    else if(self.uiWebView) {
        [self.uiWebView loadRequest:request];
    }
}

- (void)loadURLString:(NSString *)URLString {
    NSURL *URL = [NSURL URLWithString:URLString];
    [self loadURL:URL];
}

- (void)setTintColor:(UIColor *)tintColor {
    _tintColor = tintColor;
    [self.progressView setTintColor:tintColor];
    [self.navigationController.navigationBar setTintColor:tintColor];
    [self.navigationController.toolbar setTintColor:tintColor];
}

- (void)setBarTintColor:(UIColor *)barTintColor {
    _barTintColor = barTintColor;
    [self.navigationController.navigationBar setBarTintColor:barTintColor];
    [self.navigationController.toolbar setBarTintColor:barTintColor];
}

- (void)setActionButtonHidden:(BOOL)actionButtonHidden {
    _actionButtonHidden = actionButtonHidden;
    [self updateToolbarState];
}

- (void)refreshWebView
{
    if(self.wkWebView) {
        [self.wkWebView stopLoading];
        if(!self.wkWebView.URL && self.wkWebViewCurrentURL) {
            [self loadURL:self.wkWebViewCurrentURL];
        }
        else {
            [self.wkWebView reload];
        }
    }
    else if(self.uiWebView) {
        [self.uiWebView stopLoading];
        [self.uiWebView reload];
    }
}

- (void)setValue:(NSString *)value forHTTPHeaderField:(NSString *)field {
	if (value) {
		self.HTTPHeaders[field] = value;
	} else {
		[self.HTTPHeaders removeObjectForKey:field];
	}
}

- (NSString *)valueForHTTPHeaderField:(NSString *)field {
	return self.HTTPHeaders[field];
}

#pragma mark - UIWebViewDelegate

- (BOOL)webView:(UIWebView *)webView shouldStartLoadWithRequest:(NSURLRequest *)request navigationType:(UIWebViewNavigationType)navigationType {
    if(webView == self.uiWebView) {
        if([self.delegate respondsToSelector:@selector(webBrowser:shouldStartLoadWithRequest:navigationType:)]) {
            KINWebBrowserNavigationType translatedType = (KINWebBrowserNavigationType)navigationType;

            // These are all identical to their WKNavigationType (and hence KINWebBrowserNavigationType) counterparts, with
            // the exception of Other:
            if(navigationType == UIWebViewNavigationTypeOther) translatedType = KINWebBrowserNavigationTypeOther;

            BOOL decision = [self.delegate webBrowser:self shouldStartLoadWithRequest:request navigationType:translatedType];
            if(!decision)
                return NO;
        }

        self.uiWebViewCurrentURL = request.URL;
        self.uiWebViewIsLoading = YES;
        [self updateToolbarState];
        
        [self fakeProgressViewStartLoading];
        
        if([self.delegate respondsToSelector:@selector(webBrowser:didStartLoadingURL:)]) {
            [self.delegate webBrowser:self didStartLoadingURL:request.URL];
        }
    }
    return YES;
}

- (void)webViewDidFinishLoad:(UIWebView *)webView {
    if(webView == self.uiWebView) {
        if(!self.uiWebView.isLoading) {
            self.uiWebViewIsLoading = NO;
            [self updateToolbarState];
            
            [self fakeProgressBarStopLoading];
        }
        
        if([self.delegate respondsToSelector:@selector(webBrowser:didFinishLoadingURL:)]) {
            [self.delegate webBrowser:self didFinishLoadingURL:self.uiWebView.request.URL];
        }
    }
}

- (void)webView:(UIWebView *)webView didFailLoadWithError:(NSError *)error {
    if(webView == self.uiWebView) {
        if(!self.uiWebView.isLoading) {
            self.uiWebViewIsLoading = NO;
            [self updateToolbarState];
            
            [self fakeProgressBarStopLoading];
        }
        if([self.delegate respondsToSelector:@selector(webBrowser:didFailToLoadURL:error:)]) {
            [self.delegate webBrowser:self didFailToLoadURL:self.uiWebView.request.URL error:error];
        }
    }
}

#pragma mark - WKNavigationDelegate

- (void)webView:(WKWebView *)webView decidePolicyForNavigationAction:(WKNavigationAction *)navigationAction decisionHandler:(void (^)(WKNavigationActionPolicy))decisionHandler
{
    if(webView == self.wkWebView) {
        KINWebBrowserNavigationType navigationType = (KINWebBrowserNavigationType)navigationAction.navigationType;

        if([self.delegate respondsToSelector:@selector(webBrowser:shouldStartLoadWithRequest:navigationType:)]) {
            BOOL decision = [self.delegate webBrowser:self shouldStartLoadWithRequest:navigationAction.request navigationType:navigationType];
            decisionHandler(decision ? WKNavigationActionPolicyAllow : WKNavigationActionPolicyCancel);
        }
        else
            decisionHandler(WKNavigationActionPolicyAllow);
    }
    else
        decisionHandler(WKNavigationActionPolicyAllow);
}

- (void)webView:(WKWebView *)webView didStartProvisionalNavigation:(WKNavigation *)navigation {
    if(webView == self.wkWebView) {
        self.wkWebViewCurrentURL = webView.URL;
        [self updateToolbarState];
        if([self.delegate respondsToSelector:@selector(webBrowser:didStartLoadingURL:)]) {
            [self.delegate webBrowser:self didStartLoadingURL:self.wkWebView.URL];
        }
    }
}

- (void)webView:(WKWebView *)webView didFinishNavigation:(WKNavigation *)navigation {
    if(webView == self.wkWebView) {
        [self updateToolbarState];
        if([self.delegate respondsToSelector:@selector(webBrowser:didFinishLoadingURL:)]) {
            [self.delegate webBrowser:self didFinishLoadingURL:self.wkWebView.URL];
        }
    }
}

- (void)webView:(WKWebView *)webView didFailProvisionalNavigation:(WKNavigation *)navigation
      withError:(NSError *)error {
    if(webView == self.wkWebView) {
        [self updateToolbarState];
        if([self.delegate respondsToSelector:@selector(webBrowser:didFailToLoadURL:error:)]) {
            [self.delegate webBrowser:self didFailToLoadURL:self.wkWebView.URL error:error];
        }
    }
}

- (void)webView:(WKWebView *)webView didFailNavigation:(WKNavigation *)navigation
      withError:(NSError *)error {
    if(webView == self.wkWebView) {
        [self updateToolbarState];
        if([self.delegate respondsToSelector:@selector(webBrowser:didFailToLoadURL:error:)]) {
            [self.delegate webBrowser:self didFailToLoadURL:self.wkWebView.URL error:error];
        }
    }
}

#pragma mark - WKUIDelegate

-(WKWebView *)webView:(WKWebView *)webView createWebViewWithConfiguration:(WKWebViewConfiguration *)configuration forNavigationAction:(WKNavigationAction *)navigationAction windowFeatures:(WKWindowFeatures *)windowFeatures
{
    // Called on target=_blank URLs. We just redirect them to the one and only browser.

    if(!navigationAction.targetFrame.isMainFrame) {
        [webView loadRequest:navigationAction.request];
    }
    
    return nil;
}

#pragma mark - Toolbar State

- (void)updateToolbarState {
    
    BOOL canGoBack = self.wkWebView.canGoBack || self.uiWebView.canGoBack;
    BOOL canGoForward = self.wkWebView.canGoForward || self.uiWebView.canGoForward;
    BOOL canRefresh = self.wkWebViewCurrentURL || self.uiWebViewCurrentURL;  // Enable refreshing even if the WKWebView has no URL
    BOOL canShare = self.wkWebView.URL || self.uiWebViewCurrentURL;  // Only enable sharing if there's a visible page (i.e., the WKWebView has a URL)
    
    [self.backButton setEnabled:canGoBack];
    [self.forwardButton setEnabled:canGoForward];
    [self.refreshButton setEnabled:canRefresh];
    [self.actionButton setEnabled:canShare];
    
    if(!self.backButton) {
        [self setupToolbarItems];
    }
    
    NSArray *barButtonItems;
    if(self.wkWebView.loading || self.uiWebViewIsLoading) {
        barButtonItems = @[self.backButton, self.fixedSeparator, self.forwardButton, self.fixedSeparator, self.stopButton, self.flexibleSeparator];
        
        if(self.showsURLInNavigationBar) {
            [self showURLInNavigationBar];
        }
    }
    else {
        barButtonItems = @[self.backButton, self.fixedSeparator, self.forwardButton, self.fixedSeparator, self.refreshButton, self.flexibleSeparator];
        
        if(self.showsPageTitleInNavigationBar) {
            if(self.wkWebView) {
                self.navigationItem.title = self.wkWebView.title;
            }
            else if(self.uiWebView) {
                self.navigationItem.title = [self.uiWebView stringByEvaluatingJavaScriptFromString:@"document.title"];
            }

            // Fall back on the URL if showsURLInNavigationBar and the page has no title.
            if(self.showsURLInNavigationBar && self.navigationItem.title.length == 0) {
                [self showURLInNavigationBar];
            }
        }
    }
    
    if(!self.actionButtonHidden) {
        NSMutableArray *mutableBarButtonItems = [NSMutableArray arrayWithArray:barButtonItems];
        [mutableBarButtonItems addObject:self.actionButton];
        barButtonItems = [NSArray arrayWithArray:mutableBarButtonItems];
    }
    
    [self setToolbarItems:barButtonItems animated:YES];
}

- (void)setupToolbarItems {
    self.refreshButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemRefresh target:self action:@selector(refreshButtonPressed:)];
    self.stopButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemStop target:self action:@selector(stopButtonPressed:)];
    self.backButton = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"backbutton"] style:UIBarButtonItemStylePlain target:self action:@selector(backButtonPressed:)];
    self.forwardButton = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"forwardbutton"] style:UIBarButtonItemStylePlain target:self action:@selector(forwardButtonPressed:)];
    self.actionButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAction target:self action:@selector(actionButtonPressed:)];
    self.fixedSeparator = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFixedSpace target:nil action:nil];
    self.fixedSeparator.width = 50.0f;
    self.flexibleSeparator = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil];
}

- (void)showURLInNavigationBar
{
    NSString *URLString;
    if(self.wkWebView) {
        URLString = [self.wkWebView.URL absoluteString];
        if(!URLString) {
            URLString = [self.wkWebViewCurrentURL absoluteString];
        }
    }
    else if(self.uiWebView) {
        URLString = [self.uiWebViewCurrentURL absoluteString];
    }

    if(URLString.length > 0) {
        URLString = [URLString stringByReplacingOccurrencesOfString:@"http://" withString:@""];
        URLString = [URLString stringByReplacingOccurrencesOfString:@"https://" withString:@""];
        URLString = [URLString substringToIndex:[URLString length]-1];
    }

    self.navigationItem.title = URLString;
}

#pragma mark - Done Button Action

- (void)doneButtonPressed:(id)sender {
    [self dismissAnimated:YES];
}

#pragma mark - UIBarButtonItem Target Action Methods

- (void)backButtonPressed:(id)sender {
    
    if(self.wkWebView) {
        [self.wkWebView goBack];
    }
    else if(self.uiWebView) {
        [self.uiWebView goBack];
    }
    [self updateToolbarState];
}

- (void)forwardButtonPressed:(id)sender {
    if(self.wkWebView) {
        [self.wkWebView goForward];
    }
    else if(self.uiWebView) {
        [self.uiWebView goForward];
    }
    [self updateToolbarState];
}

- (void)refreshButtonPressed:(id)sender {
    [self refreshWebView];
}

- (void)stopButtonPressed:(id)sender {
    if(self.wkWebView) {
        [self.wkWebView stopLoading];
    }
    else if(self.uiWebView) {
        [self.uiWebView stopLoading];
    }
}

- (void)actionButtonPressed:(id)sender {
    NSURL *URLForActivityItem;
    if(self.wkWebView) {
        URLForActivityItem = self.wkWebView.URL;
    }
    else if(self.uiWebView) {
        URLForActivityItem = self.uiWebView.request.URL;
    }

    if(!URLForActivityItem) {
        return;
    }

    dispatch_async(dispatch_get_main_queue(), ^{
        TUSafariActivity *safariActivity = [[TUSafariActivity alloc] init];
        ARChromeActivity *chromeActivity = [[ARChromeActivity alloc] init];
        UIActivityViewController *controller = [[UIActivityViewController alloc] initWithActivityItems:@[URLForActivityItem] applicationActivities:@[safariActivity, chromeActivity]];
        if(UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
            if(self.actionPopoverController) {
                [self.actionPopoverController dismissPopoverAnimated:YES];
            }
            self.actionPopoverController = [[UIPopoverController alloc] initWithContentViewController:controller];
            [self.actionPopoverController presentPopoverFromBarButtonItem:self.actionButton permittedArrowDirections: UIPopoverArrowDirectionAny animated:YES];
        }
        else {
            [self presentViewController:controller animated:YES completion:NULL];
        }
    });
}


#pragma mark - Estimated Progress KVO (WKWebView)

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    if ([keyPath isEqualToString:NSStringFromSelector(@selector(estimatedProgress))] && object == self.wkWebView) {
        [self.progressView setAlpha:1.0f];
        BOOL animated = self.wkWebView.estimatedProgress > self.progressView.progress;
        [self.progressView setProgress:self.wkWebView.estimatedProgress animated:animated];
        
        // Once complete, fade out UIProgressView
        if(self.wkWebView.estimatedProgress >= 1.0f) {
            [UIView animateWithDuration:0.3f delay:0.3f options:UIViewAnimationOptionCurveEaseOut animations:^{
                [self.progressView setAlpha:0.0f];
            } completion:^(BOOL finished) {
                [self.progressView setProgress:0.0f animated:NO];
            }];
        }
    }
    else {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}


#pragma mark - Fake Progress Bar Control (UIWebView)

- (void)fakeProgressViewStartLoading {
    [self.progressView setProgress:0.0f animated:NO];
    [self.progressView setAlpha:1.0f];
    
    if(!self.fakeProgressTimer) {
        self.fakeProgressTimer = [NSTimer scheduledTimerWithTimeInterval:1.0f/60.0f target:self selector:@selector(fakeProgressTimerDidFire:) userInfo:nil repeats:YES];
    }
}

- (void)fakeProgressBarStopLoading {
    if(self.fakeProgressTimer) {
        [self.fakeProgressTimer invalidate];
    }
    
    if(self.progressView) {
        [self.progressView setProgress:1.0f animated:YES];
        [UIView animateWithDuration:0.3f delay:0.3f options:UIViewAnimationOptionCurveEaseOut animations:^{
            [self.progressView setAlpha:0.0f];
        } completion:^(BOOL finished) {
            [self.progressView setProgress:0.0f animated:NO];
        }];
    }
}

- (void)fakeProgressTimerDidFire:(id)sender {
    CGFloat increment = 0.005/(self.progressView.progress + 0.2);
    if([self.uiWebView isLoading]) {
        CGFloat progress = (self.progressView.progress < 0.75f) ? self.progressView.progress + increment : self.progressView.progress + 0.0005;
        if(self.progressView.progress < 0.95) {
            [self.progressView setProgress:progress animated:YES];
        }
    }
}

#pragma mark - Dismiss

- (void)dismissAnimated:(BOOL)animated {
    [self.navigationController dismissViewControllerAnimated:animated completion:nil];
}

#pragma mark - Interface Orientation

- (NSUInteger)supportedInterfaceOrientations {
    return UIInterfaceOrientationMaskAllButUpsideDown;
}

- (BOOL)shouldAutorotate {
    return YES;
}

#pragma mark - Dealloc

- (void)dealloc {
    [self.uiWebView setDelegate:nil];
    
    [self.wkWebView setNavigationDelegate:nil];
    [self.wkWebView setUIDelegate:nil];
    if ([self isViewLoaded]) {
        [self.wkWebView removeObserver:self forKeyPath:NSStringFromSelector(@selector(estimatedProgress))];
    }
}


@end

@implementation UINavigationController(KINWebBrowser)

- (KINWebBrowserViewController *)rootWebBrowser {
    UIViewController *rootViewController = [self.viewControllers objectAtIndex:0];
    return (KINWebBrowserViewController *)rootViewController;
}

@end

/*
 Licensed to the Apache Software Foundation (ASF) under one
 or more contributor license agreements.  See the NOTICE file
 distributed with this work for additional information
 regarding copyright ownership.  The ASF licenses this file
 to you under the Apache License, Version 2.0 (the
 "License"); you may not use this file except in compliance
 with the License.  You may obtain a copy of the License at

 http://www.apache.org/licenses/LICENSE-2.0

 Unless required by applicable law or agreed to in writing,
 software distributed under the License is distributed on an
 "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
 KIND, either express or implied.  See the License for the
 specific language governing permissions and limitations
 under the License.
 */

#import "CDVInAppBrowserBeta.h"
#import <Cordova/CDVPluginResult.h>
#import <Cordova/CDVUserAgentUtil.h>
#import <Cordova/CDVJSON.h>

#define    kInAppBrowserTargetSelf @"_self"
#define    kInAppBrowserTargetSystem @"_system"
#define    kInAppBrowserTargetBlank @"_blank"

#define    kInAppBrowserToolbarBarPositionBottom @"bottom"
#define    kInAppBrowserToolbarBarPositionTop @"top"

#define    TOOLBAR_HEIGHT 44.0
#define    LOCATIONBAR_HEIGHT 21.0
#define    TABBAR_HEIGHT 49.0
#define    FOOTER_HEIGHT ((TOOLBAR_HEIGHT) + (LOCATIONBAR_HEIGHT))

#pragma mark CDVInAppBrowserBeta

@interface CDVInAppBrowserBeta () {
	NSInteger _previousStatusBarStyle;
}
@end

@implementation CDVInAppBrowserBeta

- (CDVInAppBrowserBeta*)initWithWebView:(UIWebView*)theWebView
{
	self = [super initWithWebView:theWebView];
	if (self != nil) {
		_previousStatusBarStyle = -1;
		_callbackIdPattern = nil;
	}

	return self;
}

- (void)onReset
{
	[self close:nil];
}

- (void)hide:(CDVInvokedUrlCommand*)command
{
	//[self.inAppBrowserViewController.webView reload];
	//[self hide:nil];
	[self.inAppBrowserViewController hide];
	_previousStatusBarStyle = -1;
}

- (void)loadedStatus:(CDVInvokedUrlCommand*)command
{
	if (self.callbackId != nil) {
		NSString* loaded = [self.inAppBrowserViewController.webView stringByEvaluatingJavaScriptFromString:@"(document.getElementById('shotbowAppPageLoaded')!=null ? document.getElementById('shotbowAppPageLoaded').getAttribute('token') : 'false').toString()"];

		CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK
													  messageAsDictionary:@{@"type":@"loadedStatus", @"loaded":loaded}];
		[pluginResult setKeepCallback:[NSNumber numberWithBool:YES]];

		[self.commandDelegate sendPluginResult:pluginResult callbackId:self.callbackId];
	}
}

- (void)close:(CDVInvokedUrlCommand*)command
{
	if (self.inAppBrowserViewController == nil) {
		NSLog(@"IAB.close() called but it was already closed.");
		return;
	}
	// Things are cleaned up in browserExit.
	[self.inAppBrowserViewController close];
}

- (BOOL) isSystemUrl:(NSURL*)url
{
	if ([[url host] isEqualToString:@"itunes.apple.com"]) {
		return YES;
	}

	return NO;
}

- (void)open:(CDVInvokedUrlCommand*)command
{
	CDVPluginResult* pluginResult;

	NSString* url = [command argumentAtIndex:0];
	NSString* target = [command argumentAtIndex:1 withDefault:kInAppBrowserTargetSelf];
	NSString* options = [command argumentAtIndex:2 withDefault:@"" andClass:[NSString class]];

	self.callbackId = command.callbackId;

	if (url != nil) {
		NSURL* baseUrl = [self.webView.request URL];
		NSURL* absoluteUrl = [[NSURL URLWithString:url relativeToURL:baseUrl] absoluteURL];

		if ([self isSystemUrl:absoluteUrl]) {
			target = kInAppBrowserTargetSystem;
		}

		if ([target isEqualToString:kInAppBrowserTargetSelf]) {
			[self openInCordovaWebView:absoluteUrl withOptions:options];
		} else if ([target isEqualToString:kInAppBrowserTargetSystem]) {
			[self openInSystem:absoluteUrl];
		} else { // _blank or anything else
			[self openInInAppBrowser:absoluteUrl withOptions:options];
		}

		pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
	} else {
		pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"incorrect number of arguments"];
	}

	[pluginResult setKeepCallback:[NSNumber numberWithBool:YES]];
	[self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (void)openInInAppBrowser:(NSURL*)url withOptions:(NSString*)options
{
	CDVInAppBrowserBetaOptions* browserOptions = [CDVInAppBrowserBetaOptions parseOptions:options];

	if (browserOptions.clearcache) {
		NSHTTPCookie *cookie;
		NSHTTPCookieStorage *storage = [NSHTTPCookieStorage sharedHTTPCookieStorage];
		for (cookie in [storage cookies])
		{
			if (![cookie.domain isEqual: @".^filecookies^"]) {
				[storage deleteCookie:cookie];
			}
		}
	}

	if (browserOptions.clearsessioncache) {
		NSHTTPCookie *cookie;
		NSHTTPCookieStorage *storage = [NSHTTPCookieStorage sharedHTTPCookieStorage];
		for (cookie in [storage cookies])
		{
			if (![cookie.domain isEqual: @".^filecookies^"] && cookie.isSessionOnly) {
				[storage deleteCookie:cookie];
			}
		}
	}

	if (self.inAppBrowserViewController == nil) {
		NSString* originalUA = [CDVUserAgentUtil originalUserAgent];
		//NSString* originalUA = @"Mozilla/5.0 (Macintosh; Intel Mac OS X 10_9_3) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/35.0.1916.153 Safari/537.36";
		self.inAppBrowserViewController = [[CDVInAppBrowserBetaViewController alloc] initWithUserAgent:originalUA prevUserAgent:[self.commandDelegate userAgent] browserOptions: browserOptions];
		self.inAppBrowserViewController.navigationDelegate = self;

		if ([self.viewController conformsToProtocol:@protocol(CDVScreenOrientationDelegate)]) {
			self.inAppBrowserViewController.orientationDelegate = (UIViewController <CDVScreenOrientationDelegate>*)self.viewController;
		}
	}

	[self.inAppBrowserViewController showLocationBar:browserOptions.location];
	[self.inAppBrowserViewController showToolBar:browserOptions.toolbar :browserOptions.toolbarposition];
	[self.inAppBrowserViewController showTabBar:browserOptions.tabbar :browserOptions.tabbarinit];

	if (browserOptions.closebuttoncaption != nil) {
		[self.inAppBrowserViewController setCloseButtonTitle:browserOptions.closebuttoncaption];
	}
	// Set Presentation Style
	UIModalPresentationStyle presentationStyle = UIModalPresentationFullScreen; // default
	if (browserOptions.presentationstyle != nil) {
		if ([[browserOptions.presentationstyle lowercaseString] isEqualToString:@"pagesheet"]) {
			presentationStyle = UIModalPresentationPageSheet;
		} else if ([[browserOptions.presentationstyle lowercaseString] isEqualToString:@"formsheet"]) {
			presentationStyle = UIModalPresentationFormSheet;
		}
	}
	self.inAppBrowserViewController.modalPresentationStyle = presentationStyle;

	// Set Transition Style
	UIModalTransitionStyle transitionStyle = UIModalTransitionStyleCoverVertical; // default
	if (browserOptions.transitionstyle != nil) {
		if ([[browserOptions.transitionstyle lowercaseString] isEqualToString:@"fliphorizontal"]) {
			transitionStyle = UIModalTransitionStyleFlipHorizontal;
		} else if ([[browserOptions.transitionstyle lowercaseString] isEqualToString:@"crossdissolve"]) {
			transitionStyle = UIModalTransitionStyleCrossDissolve;
		}
	}
	self.inAppBrowserViewController.modalTransitionStyle = transitionStyle;

	// prevent webView from bouncing
	if (browserOptions.disallowoverscroll) {
		if ([self.inAppBrowserViewController.webView respondsToSelector:@selector(scrollView)]) {
			((UIScrollView*)[self.inAppBrowserViewController.webView scrollView]).bounces = NO;
		} else {
			for (id subview in self.inAppBrowserViewController.webView.subviews) {
				if ([[subview class] isSubclassOfClass:[UIScrollView class]]) {
					((UIScrollView*)subview).bounces = NO;
				}
			}
		}
	}

	// UIWebView options
	self.inAppBrowserViewController.webView.scalesPageToFit = browserOptions.enableviewportscale;
	self.inAppBrowserViewController.webView.mediaPlaybackRequiresUserAction = browserOptions.mediaplaybackrequiresuseraction;
	self.inAppBrowserViewController.webView.allowsInlineMediaPlayback = browserOptions.allowinlinemediaplayback;
	if (IsAtLeastiOSVersion(@"6.0")) {
		self.inAppBrowserViewController.webView.keyboardDisplayRequiresUserAction = browserOptions.keyboarddisplayrequiresuseraction;
		self.inAppBrowserViewController.webView.suppressesIncrementalRendering = browserOptions.suppressesincrementalrendering;
	}

	[self.inAppBrowserViewController navigateTo:url];
	if (!browserOptions.hidden) {
		[self show:nil];
	}
}

- (void)show:(CDVInvokedUrlCommand*)command
{
	if (self.inAppBrowserViewController == nil) {
		NSLog(@"Tried to show IAB after it was closed.");
		return;
	}
	if (_previousStatusBarStyle != -1) {
		NSLog(@"Tried to show IAB while already shown");
		return;
	}

	_previousStatusBarStyle = [UIApplication sharedApplication].statusBarStyle;

	CDVInAppBrowserBetaNavigationController* nav = [[CDVInAppBrowserBetaNavigationController alloc]
								   initWithRootViewController:self.inAppBrowserViewController];
	nav.orientationDelegate = self.inAppBrowserViewController;
	nav.navigationBarHidden = YES;
	// Run later to avoid the "took a long time" log message.
	dispatch_async(dispatch_get_main_queue(), ^{
		if (self.inAppBrowserViewController != nil) {
			[self.viewController presentViewController:nav animated:YES completion:nil];
		}
	});
}

- (void)openInCordovaWebView:(NSURL*)url withOptions:(NSString*)options
{
	if ([self.commandDelegate URLIsWhitelisted:url]) {
		NSURLRequest* request = [NSURLRequest requestWithURL:url];
		[self.webView loadRequest:request];
	} else { // this assumes the InAppBrowser can be excepted from the white-list
		[self openInInAppBrowser:url withOptions:options];
	}
}

- (void)openInSystem:(NSURL*)url
{
	if ([[UIApplication sharedApplication] canOpenURL:url]) {
		[[UIApplication sharedApplication] openURL:url];
	} else { // handle any custom schemes to plugins
		[[NSNotificationCenter defaultCenter] postNotification:[NSNotification notificationWithName:CDVPluginHandleOpenURLNotification object:url]];
	}
}

// This is a helper method for the inject{Script|Style}{Code|File} API calls, which
// provides a consistent method for injecting JavaScript code into the document.
//
// If a wrapper string is supplied, then the source string will be JSON-encoded (adding
// quotes) and wrapped using string formatting. (The wrapper string should have a single
// '%@' marker).
//
// If no wrapper is supplied, then the source string is executed directly.

- (void)injectDeferredObject:(NSString*)source withWrapper:(NSString*)jsWrapper
{
	if (!_injectedIframeBridge) {
		_injectedIframeBridge = YES;
		// Create an iframe bridge in the new document to communicate with the CDVInAppBrowserBetaViewController
		[self.inAppBrowserViewController.webView stringByEvaluatingJavaScriptFromString:@"(function(d){var e = _cdvIframeBridge = d.createElement('iframe');e.style.display='none';d.body.appendChild(e);})(document)"];
	}

	if (jsWrapper != nil) {
		NSString* sourceArrayString = [@[source] JSONString];
		if (sourceArrayString) {
			NSString* sourceString = [sourceArrayString substringWithRange:NSMakeRange(1, [sourceArrayString length] - 2)];
			NSString* jsToInject = [NSString stringWithFormat:jsWrapper, sourceString];
			[self.inAppBrowserViewController.webView stringByEvaluatingJavaScriptFromString:jsToInject];
		}
	} else {
		[self.inAppBrowserViewController.webView stringByEvaluatingJavaScriptFromString:source];
	}
}

- (void)injectScriptCode:(CDVInvokedUrlCommand*)command
{
	NSString* jsWrapper = nil;

	if ((command.callbackId != nil) && ![command.callbackId isEqualToString:@"INVALID"]) {
		jsWrapper = [NSString stringWithFormat:@"_cdvIframeBridge.src='gap-iab://%@/'+encodeURIComponent(JSON.stringify([eval(%%@)]));", command.callbackId];
	}
	[self injectDeferredObject:[command argumentAtIndex:0] withWrapper:jsWrapper];
}

- (void)injectScriptFile:(CDVInvokedUrlCommand*)command
{
	NSString* jsWrapper;

	if ((command.callbackId != nil) && ![command.callbackId isEqualToString:@"INVALID"]) {
		jsWrapper = [NSString stringWithFormat:@"if (document.body && typeof document.body !== 'undefined') { (function(d) { var c = d.createElement('script'); if (!c || typeof c === 'undefined') { return; } c.src = %%@; c.onload = function() { _cdvIframeBridge.src='gap-iab://%@'; }; d.body.appendChild(c); })(document) }", command.callbackId];
	} else {
		jsWrapper = @"if (document.body && typeof document.body !== 'undefined') { (function(d) { var c = d.createElement('script'); if (!c || typeof c === 'undefined') { return; } c.src = %@;d.body.appendChild(c); })(document) }";
	}
	[self injectDeferredObject:[command argumentAtIndex:0] withWrapper:jsWrapper];
}

- (void)injectStyleCode:(CDVInvokedUrlCommand*)command
{
	NSString* jsWrapper;

	if ((command.callbackId != nil) && ![command.callbackId isEqualToString:@"INVALID"]) {
		jsWrapper = [NSString stringWithFormat:@"if (document.body && typeof document.body !== 'undefined') { (function(d) { var c = d.createElement('style'); if (!c || typeof c === 'undefined') { return; } c.innerHTML = %%@; c.onload = function() { _cdvIframeBridge.src='gap-iab://%@'; }; d.body.appendChild(c); })(document) }", command.callbackId];
	} else {
		jsWrapper = @"if (document.body && typeof document.body !== 'undefined') { (function(d) { var c = d.createElement('style'); if (!c || typeof c === 'undefined') { return; } c.innerHTML = %@; d.body.appendChild(c); })(document) }";
	}
	[self injectDeferredObject:[command argumentAtIndex:0] withWrapper:jsWrapper];
}

- (void)injectStyleFile:(CDVInvokedUrlCommand*)command
{
	NSString* jsWrapper;

	if ((command.callbackId != nil) && ![command.callbackId isEqualToString:@"INVALID"]) {
		jsWrapper = [NSString stringWithFormat:@"if (document.body && typeof document.body !== 'undefined') { (function(d) { var c = d.createElement('link'); if (!c || typeof c === 'undefined') { return; } c.rel='stylesheet'; c.type='text/css'; c.href = %%@; c.onload = function() { _cdvIframeBridge.src='gap-iab://%@'; }; d.body.appendChild(c); })(document) }", command.callbackId];
	} else {
		jsWrapper = @"if (document.body && typeof document.body !== 'undefined') { (function(d) { var c = d.createElement('link'); if (!c || typeof c === 'undefined') { return; } c.rel='stylesheet', c.type='text/css'; c.href = %@; d.body.appendChild(c); })(document) }";
	}
	[self injectDeferredObject:[command argumentAtIndex:0] withWrapper:jsWrapper];
}

- (BOOL)isValidCallbackId:(NSString *)callbackId
{
	NSError *err = nil;
	// Initialize on first use
	if (self.callbackIdPattern == nil) {
		self.callbackIdPattern = [NSRegularExpression regularExpressionWithPattern:@"^InAppBrowser[0-9]{1,10}$" options:0 error:&err];
		if (err != nil) {
			// Couldn't initialize Regex; No is safer than Yes.
			return NO;
		}
	}
	if ([self.callbackIdPattern firstMatchInString:callbackId options:0 range:NSMakeRange(0, [callbackId length])]) {
		return YES;
	}
	return NO;
}

/**
 * The iframe bridge provided for the InAppBrowser is capable of executing any oustanding callback belonging
 * to the InAppBrowser plugin. Care has been taken that other callbacks cannot be triggered, and that no
 * other code execution is possible.
 *
 * To trigger the bridge, the iframe (or any other resource) should attempt to load a url of the form:
 *
 * gap-iab://<callbackId>/<arguments>
 *
 * where <callbackId> is the string id of the callback to trigger (something like "InAppBrowser0123456789")
 *
 * If present, the path component of the special gap-iab:// url is expected to be a URL-escaped JSON-encoded
 * value to pass to the callback. [NSURL path] should take care of the URL-unescaping, and a JSON_EXCEPTION
 * is returned if the JSON is invalid.
 */
- (BOOL)webView:(UIWebView*)theWebView shouldStartLoadWithRequest:(NSURLRequest*)request navigationType:(UIWebViewNavigationType)navigationType
{
	NSURL* url = request.URL;
	BOOL isTopLevelNavigation = [request.URL isEqual:[request mainDocumentURL]];

	// See if the url uses the 'gap-iab' protocol. If so, the host should be the id of a callback to execute,
	// and the path, if present, should be a JSON-encoded value to pass to the callback.
	if ([[url scheme] isEqualToString:@"gap-iab"]) {
		NSString* scriptCallbackId = [url host];
		CDVPluginResult* pluginResult = nil;

		if ([self isValidCallbackId:scriptCallbackId]) {
			NSString* scriptResult = [url path];
			NSError* __autoreleasing error = nil;

			// The message should be a JSON-encoded array of the result of the script which executed.
			if ((scriptResult != nil) && ([scriptResult length] > 1)) {
				scriptResult = [scriptResult substringFromIndex:1];
				NSData* decodedResult = [NSJSONSerialization JSONObjectWithData:[scriptResult dataUsingEncoding:NSUTF8StringEncoding] options:kNilOptions error:&error];
				if ((error == nil) && [decodedResult isKindOfClass:[NSArray class]]) {
					pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsArray:(NSArray*)decodedResult];
				} else {
					pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_JSON_EXCEPTION];
				}
			} else {
				pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsArray:@[]];
			}
			[self.commandDelegate sendPluginResult:pluginResult callbackId:scriptCallbackId];
			return NO;
		}
	} else if ((self.callbackId != nil) && isTopLevelNavigation) {
		// Send a loadstart event for each top-level navigation (includes redirects).
		CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK
													  messageAsDictionary:@{@"type":@"loadstart", @"url":[url absoluteString]}];
		[pluginResult setKeepCallback:[NSNumber numberWithBool:YES]];

		[self.commandDelegate sendPluginResult:pluginResult callbackId:self.callbackId];
	}

	return YES;
}

- (void)webViewDidStartLoad:(UIWebView*)theWebView
{
	_injectedIframeBridge = NO;
}

- (void)webViewDidFinishLoad:(UIWebView*)theWebView
{
	if (self.callbackId != nil) {
		// TODO: It would be more useful to return the URL the page is actually on (e.g. if it's been redirected).
		NSString* url = [self.inAppBrowserViewController.currentURL absoluteString];
		CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK
													  messageAsDictionary:@{@"type":@"loadstop", @"url":url}];
		[pluginResult setKeepCallback:[NSNumber numberWithBool:YES]];

		[self.commandDelegate sendPluginResult:pluginResult callbackId:self.callbackId];
	}
}

- (void)webView:(UIWebView*)theWebView didFailLoadWithError:(NSError*)error
{
	if (self.callbackId != nil) {
		NSString* url = [self.inAppBrowserViewController.currentURL absoluteString];
		CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR
													  messageAsDictionary:@{@"type":@"loaderror", @"url":url, @"code": [NSNumber numberWithInteger:error.code], @"message": error.localizedDescription}];
		[pluginResult setKeepCallback:[NSNumber numberWithBool:YES]];

		[self.commandDelegate sendPluginResult:pluginResult callbackId:self.callbackId];
	}
}







// Tabbar testing
- (void)toolbarItemTapped:(NSInteger)tabIndex
{
	if (self.callbackId != nil) {
		NSString *inStr = [@(tabIndex) stringValue];
		CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK
													   messageAsDictionary:@{@"type":@"toolbarItemTapped", @"index":inStr}];
		[self.commandDelegate sendPluginResult:pluginResult callbackId:self.callbackId];
	}
}








- (void)browserExit
{
	if (self.callbackId != nil) {
		CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK
													  messageAsDictionary:@{@"type":@"exit"}];
		[self.commandDelegate sendPluginResult:pluginResult callbackId:self.callbackId];
		self.callbackId = nil;
	}
	// Set navigationDelegate to nil to ensure no callbacks are received from it.
	self.inAppBrowserViewController.navigationDelegate = nil;
	// Don't recycle the ViewController since it may be consuming a lot of memory.
	// Also - this is required for the PDF/User-Agent bug work-around.
	self.inAppBrowserViewController = nil;

	if (IsAtLeastiOSVersion(@"7.0")) {
		[[UIApplication sharedApplication] setStatusBarStyle:_previousStatusBarStyle];
	}

	_previousStatusBarStyle = -1; // this value was reset before reapplying it. caused statusbar to stay black on ios7
}

@end

#pragma mark CDVInAppBrowserBetaViewController

@implementation CDVInAppBrowserBetaViewController

@synthesize currentURL;

- (id)initWithUserAgent:(NSString*)userAgent prevUserAgent:(NSString*)prevUserAgent browserOptions: (CDVInAppBrowserBetaOptions*) browserOptions
{
	self = [super init];
	if (self != nil) {
		_userAgent = userAgent;
		_prevUserAgent = prevUserAgent;
		_browserOptions = browserOptions;
		_webViewDelegate = [[CDVWebViewDelegate alloc] initWithDelegate:self];
		[self createViews];
	}

	return self;
}

- (void)createViews
{
	// We create the views in code for primarily for ease of upgrades and not requiring an external .xib to be included

	CGRect webViewBounds = self.view.bounds;
	BOOL toolbarIsAtBottom = ![_browserOptions.toolbarposition isEqualToString:kInAppBrowserToolbarBarPositionTop];
	float tabBarHeight = TABBAR_HEIGHT;
	if ([[self platform] rangeOfString:@"iPad"].location != NSNotFound) {
		tabBarHeight = 56.0;
	}
	webViewBounds.size.height -= (_browserOptions.location ? FOOTER_HEIGHT : TOOLBAR_HEIGHT) + tabBarHeight;
	self.webView = [[UIWebView alloc] initWithFrame:webViewBounds];

	self.webView.autoresizingMask = (UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight);

	[self.view addSubview:self.webView];
	[self.view sendSubviewToBack:self.webView];

	self.webView.delegate = _webViewDelegate;
	self.webView.backgroundColor = [UIColor colorWithRed:16/255.0f green:15/255.0f blue:15/255.0f alpha:1.0f];

	self.webView.clearsContextBeforeDrawing = YES;
	self.webView.clipsToBounds = YES;
	self.webView.contentMode = UIViewContentModeScaleToFill;
	self.webView.multipleTouchEnabled = YES;
	self.webView.opaque = YES;
	self.webView.scalesPageToFit = NO;
	self.webView.userInteractionEnabled = YES;

	self.spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhite];
	self.spinner.alpha = 1.000;
	self.spinner.autoresizesSubviews = YES;
	self.spinner.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleTopMargin;
	self.spinner.clearsContextBeforeDrawing = NO;
	self.spinner.clipsToBounds = NO;
	self.spinner.contentMode = UIViewContentModeScaleToFill;
	self.spinner.frame = CGRectMake(454.0, 231.0, 20.0, 20.0);
	self.spinner.hidden = YES;
	self.spinner.hidesWhenStopped = YES;
	self.spinner.multipleTouchEnabled = NO;
	self.spinner.opaque = NO;
	self.spinner.userInteractionEnabled = NO;
	[self.spinner stopAnimating];

	self.closeButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(close)];
	self.closeButton.enabled = NO;

	UIBarButtonItem* flexibleSpaceButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil];

	UIBarButtonItem* fixedSpaceButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFixedSpace target:nil action:nil];
	fixedSpaceButton.width = 20;

	float toolbarY = toolbarIsAtBottom ? self.view.bounds.size.height - TOOLBAR_HEIGHT : 0.0;
	CGRect toolbarFrame = CGRectMake(0.0, toolbarY, self.view.bounds.size.width, TOOLBAR_HEIGHT);

	self.toolbar = [[UIToolbar alloc] initWithFrame:toolbarFrame];
	self.toolbar.alpha = 1.000;
	self.toolbar.autoresizesSubviews = YES;
	self.toolbar.autoresizingMask = toolbarIsAtBottom ? (UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin) : UIViewAutoresizingFlexibleWidth;
	self.toolbar.barStyle = UIBarStyleBlackOpaque;
	self.toolbar.barTintColor = [UIColor colorWithRed:189/255.0f green:63/255.0f blue:51/255.0f alpha:1.0f];
	self.toolbar.clearsContextBeforeDrawing = NO;
	self.toolbar.clipsToBounds = YES;
	self.toolbar.contentMode = UIViewContentModeScaleToFill;
	self.toolbar.hidden = NO;
	self.toolbar.multipleTouchEnabled = NO;
	self.toolbar.opaque = NO;
	self.toolbar.userInteractionEnabled = YES;





	// Tab bar testing
	float tabBarHeight = TABBAR_HEIGHT;
	if ([[self platform] rangeOfString:@"iPad"].location != NSNotFound) {
		tabBarHeight = 56.0;
	}

	float tabBarY = self.view.bounds.size.height - tabBarHeight;

	self.tabBar = [[UITabBar alloc] initWithFrame:CGRectMake(0, tabBarY, self.view.bounds.size.width, tabBarHeight)];
	NSMutableArray *tabBarItems = [[NSMutableArray alloc] init];

	// Sigh, I donm't know how to reference img assets in AppGyver into the plugin
	// Home
	NSString *tab1Base64 = @"data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAADwAAAA8CAYAAAA6/NlyAAADgUlEQVR4nO2ay2sVVxzHv3mpVRt8pAvfVQzUhRvfldZUBAXBVQVBF6IiKv0TNKjgRhAFQQzUbkrFFhoUqYWKj0WUiGJVVFBDKYL4QsFN1KQ2ny7mXHO8uXPmzL13ptfJfGEWOef7m/l+Muf+zjD31gEaTqr/vwOkrRw468qBs64cOOtqTPl6kyXtlbTC/P2HpHZJLxw1HcZfV2IOSeclbfcNUJfig8cySZ2SWorGH0paJel+SN2ASsMWhGKs1LSW9BZJ5zQUVpJmSLos6cuQWhesz/wHShq4XtJBScckNTl8ExUszTUJ50l0STdLOiFpdYyafyVtk/SDNeYT0PsuJ3WHZ0nqVjjsW3MUq0HBamhPKJcEVPtoA14QrifAYmAJ8MzhOwo0OOZteeerNuwWoN8R7CYwzfLPAG47/CdrFbgeOBgR6hQwxvjHmkPAp8AZT7CaAG72CLyf4J8iYDpwi+BuTzdjDcDhjwF4FnDXEaQP2Gj5lwBPrfmnZqwwvwP4p1aB23A3p+fAV5Z/A/C2hO8NsN7yrQRe1RpwVHO6A8w03jpgn0fofcYrYA7wlycscbLHBfVpTmcIPtcCRgOdMYL/amoEtABdnnWJAPs0p0MEDUjAVOBPz8C2rgNTzDlGAD961BQaYtWAo5pTP7DV8i8CHvszDtFjYKF1vp3AgMN/mmB7qwpwG+7m9BJYbvnXETSiSvXanKtw3rVmLEy3gc+pEDiqOd0DZjPYnPaUhRauAWC3lWcB7pXzHPiaMoAbiG5OZ4Fxxv8J8EsZQL762Vyj0BtuOLx9wCZiADcDv0cEOAI0Gv9k4Fp5HLF0FZhkrjmG4FHVpQOUaGZxm9M74DvLPx94VDZCfD0C5jG4RR6I8P/G4BZZEvi6o/gVwVNQwfst0FtB+HLVa67t22eO4QDuCCnqAb6wfLtwbxNJa4Bgqyrk+YZgtyilbTiARwKXigouAhPM/CjgeHWzV6SfCDILaAUeFM1/j0fT+gz42yposua6E41fnroZzDceuGDGL/JhdgGhL/HGSZorqav4jVBi75oqk/0Sr1HSUklXJPUPMYYAh+ljAHZq2H23lANnXWl+e9gaMd+TRog0m1ZUY0ny3O817JZ0Dpx15cBZVw6cdeXAWVdc4FQe/2Iq7PddJRUXeLNqC7pHQSZvpflLvJpQ/hnOunLgrCsHzrpy4KzrP6uTFDWZ8eH+AAAAAElFTkSuQmCC";
	// Maps
	NSString *tab2Base64 = @"data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAADwAAAA8CAYAAAA6/NlyAAAD70lEQVR4nO3bT4iXRRgH8M/utlZExbqbldFflIwwosLoUFEdSsLu3beD1KFIKLpGG1hBGdTBIAhqwQ5BEnlIioQgEyOM3LI2QyoxdWkzNNp2OsxK2262887M+xbqF36nfea73+/7zG9m3meeX08IwamE3v9aQNc4bfhkxxkd8N+Bu3ATlmEQZ+MoDuFr7MBWvI+pNgX1tLRoDeFhPIAlDcYdwEY8j4PVVUEIoeanL4TwSAhhMpRhcoanr7K+qhm+BKO4tRYhPsT9+KEWYS3DK7EFS2uQzcH3uAef1yCrYfg6fICBYjUnxgRux65SolLDl2E7LiwVkoD9WIV9JSQl+3A/3tSNWbho5v/1l5CUGH5MfOJd4masKyHIndJL8Q3OSoyfxCvYjDEcxmKswH0YxrmJXEdxlTjFmyNzP3uuwZ46GkIYWoDvghDCpgacz+buwzmDFoUQDiUKG2nA2xNCeCaR92AIob8rw/cmihrN4O4J6ZlenWM4Z9G6MyFmEg9lcAc8iF8q6ZiHHMM3JMRsFN+EcvCTuMDV0DEPOYaXJcRszuCdjbcr6ZiHHMOLE2J2Z/DOxlhCzGAOcc4+/IeFH9Qi/J4jaNb43xaImUZfU+KcDC8khPIXiZRZdCyHOMfwRELMNRm8s7Giko55yDE8nhCzJoO36fhvc4hzDO9IiBmWuaiI9bDhhLhPcshzDL+bEHM+XsjghhdxXiUd85FxPOsNIYwnHv+ebMg9ksg7PqOjk7O0EMLaRGEhhPB6CGFwAb6hEM/eqVibqTv7ffhMcdG4ODH+Z3+9D+8WV9gBcTVfI9avU6Yx/IgrpW2P85H7pEIIjzbISE2sa6CxWobhHHwnfzXOwWFcjiO5BCU1rV+xoWB8DjYoMEt5mXZAzHJqPaoER8SycNYJ6zhKr0sn8FIhRypeVmiWOjcPS7BXvAJtC8fElTmvUjkLNS7ED0irUJTgVRXMUu8y7VKxTl10K3ACTGG5OIuKUavlYR9eq8Q1F2+oZJa6HQDLxdJMzb6RaVwrreSThJri9mBTRT54S0Wz1O/xWInP0FOJ70bsrMSF+m1Lu5SXaI9ji8pmaaeLZxU+rsBzG7ZV4Pkb2mhM2473Cjm2acEs7XXiPVU4fqSKin9AW41p8BFuyRi3U1ysWkGbvZa5WW4tu7SbYfgU1zeIHxMPGtOtqNF+N23TbD2tRbO0n+FefIGrE2L3isfTVrtp287wtJi1FKzXslnazzCxZ3oPrviXmP0zf88rvTZAFx3xUxb+Lq/XgVm6yTDxwb4jdsXOxVbcLV60dyKkC0yLNwyP40uxRvUVnsBqHZmluwz/b3DK/arltOGTHX8C0QFOxRLbcsEAAAAASUVORK5CYII=";
	// Forums
	NSString *tab3Base64 = @"data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAADwAAAA8CAYAAAA6/NlyAAAFs0lEQVR4nOWbW4hVVRzGf+c4muWUmZmWjVkmgo4WiTmYJfZgaXkjiHoIDEToHhRdfOjBougCvUQkRVFPIUEUopaolIWkYWRjlImJjo7WOE6T4zgzOl8Pa+3mzPHsvdfa65wzE32wGfbZ6//t79uXtf/rv9bkJPF/Qn6gBVQbrobrgDXALqAF6AKagA3A8MpIS8Rwe+4mq6XFalsDXJ0YKSlte1bSacXjsKRFDjzl2u6W1JSg57Skp+Pi08jfSSAuxDlJD1fB7OP2XC54y9fwY47EhaaXVNDsckm9npoeKubJqXQvfTnwO1Dr+W4dA64HOjzj0lAL7AfGesa1A9cCrdEPcZ3WKvzNAowDVmaIS8NK/M0CXILx8i/iDC/KQB5hSUBsHJYGxPbzEmd4SsAJpgbEVoKzn5e4d7gHqMl4gm7ggoyxSZxDM8b2AMOinThTbZiOKwtaS/w2BJgHLABuBa4CrgD+AI4C24HNwFfA2RLxJ237LDjZby/mE/CNZ/dfiK0FPDWSVkj6zTF2v21fU6RnW4Cerwu54t7hDRmvJsBn9m8d5s59gPlUuWCSbb/dxhdzZsHGfnsqfYfHSPo7w9VsllQraY6kloC7Ihs/x+q5WNLxDBztkkbLMdN6wpO8V9IySVMltWYQVwqtlg9J98g/03pUnrk0klZL6kwgPSJpsW37kqcgV7xYoGeppKMJbTtlBjwl/cR9looxAZOx3IlJ1WqBE8AeYDnQienVD1OZ4eIZzLDvhN2/EPgUmAGMBk5hUuFNwFqroyRcDbtgBabDqRRWAB+GkhT20nOBHZirtRmTv47x4FocKiYFvinrlcBTwE+Y7/1q6LvDNwLfAhcVBfUC3wFfAt8DjZjqQo8lnAbsBpqBvVQmrYywF6i3530DeB04jnnMh2Ee7XrgZuAOYBbnp86rIsNbgNszChkBnLYnviwjhwtOYPqJEZinMAuO5CRNxLzwWTEUkw52UZCzVgBdmA5xCKXTTyfkgYWBQqIc989AnjRE/CNDSPLATYFCoiphcyBPGiL+USEkecLGvtD37u8I5ElDxF8fQpLH9HohiKoRnwfypCHinxlCkpN0Erg0UMxczOfrV+C6QK5SOIB5Es8CP2A+o5mQpzyp4MtWzPNl4CqF5yz/FALMAiD3wnYanrQJ+qYy8UXYqL7kf20oWU5SuRKGZkz5pgWTtU0rA2cjcAumvjwKk9VdA+QyM0qaKanH80Kdk/S2pJGKH1aOkLQu441YZ+OThq01MnNIp3yIo+AFko45xrRLmp8ipnBbKGm3I/du295nCmaipH0O3GckrSoMrJX0iKQvZEo13SWC2iQ1FJ3wBZlC2RGZwfd6SdOL2uQkzZa0xrY9IKnD/t0uM8BvsO2KDc2TKSp2SjokabOkZ4rajJPUWEJvh/39TUmT5FjxiNtGSfoo5mqelXnkR6dwpN25T2L4ZfnTHvvztqxiJks6mCAmwl+SXpE0wYN7mkxv3OXA/4ukOh/tWSoeY4GdmLKPc99I37h6F/AzpmCfxwz5ZmDGsYvw7933AQ0UF9xjkMXweuAu36AK42PgfpeGvoaXYYpngxELMKWpRPga3gNMz6qowtgJzE5r5LNs6TYGr1kwfcCstEY+hh/IrqVqSNXo80g3AeOD5FQeBzETBbFwvcOTGfxmASZiBhexcDWc2hkMIjQkHXQ1fG8ZhFQL9yUddDXsk1UNNOqSDroa9pljGmgkanU1XDznNJiRqNXV8EAsEc6Kshiu5JxRuZG4RszVcFu4jqqhLemgq+FD4TqqhtjlDuBueGsZhFQLW5IOuubS9cCPDP5/CukFbsDUs0vC1UAj8F45FFUY75JgFvxGS8Mwy/iyLo2oNLZgamLdSY18HtFuzDqt19JIq4xu4FWMtlRdWddpjQceBOZj5n7KvT46DV2Y+attwPuYJchOKOfCtP8E/gEJW58K4Br3ggAAAABJRU5ErkJggg==";
	// Chat
	NSString *tab4Base64 = @"data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAADwAAAA8CAYAAAA6/NlyAAADqElEQVR4nO3bSYgcVRzH8U/XxIgJDJqg4nKQQBT3TAwoHhSXAbeDiuJFwYse1IN4FldEMXrw4EXRkyieYox7XGPE0cRkSMTgBqOJaBIxIRrFTNLPw5swnU71dHVPLd1tvvBoqK5X9fv1e1Vv+f+7FkLwfyKpWkDZHDE86Mwp6Lon43wswek4BadiAY7BPAT8hb1Tn9vxQ0NZh5/yFlbL6aU1H9fgyqmyKI+LiobX4EO8ht2zveBsDCeiydtwndhqRfIv3sJLeAP7urlIN4bn407cI7+W7JRtWI7n8U9HNUMIWctRIYS7Qwi/ht5hewjh3hDCUMjoI2sLL8MLOK/TpiiJjWKvW9/uxHbDUg0PYUzvmoURfIFHRc0tmamFh/Eyrs1VWvGsxK3iUHcYrQwvwLtiV+5HNuNy/N78RZrhYXwiThr6ma9E03saDzY/w0N4Rf+bhQuwCnMbDzYbflCcTAwKl+CRxgONXXoZPlfc/Loq6rgUaznU8HqxGwwi3+Is1A926RsNrlk4Azcx3cJjuLBKRSUwjpFaCGExvqtYTFmcneD6qlWUyGiCi6pWUSJXJDi3ahUlclqC46tWUSIn1EIIkwZvstGKyUTT5HrA+SORsoQaYHYk2FK1ihKZSPBp1SpK5IMEq6tWUSKrE2zCl1UrKYFxfHNwtfRshULK4nGmV0uJuAe0pEJBRXLYerguhk4GMR2gjjumPg/Z0/oMT1ahqGCe0jASNW/TDuE9cXtzEFiDUQ2RxrR96ePwPpaWp6sQNuAybfalYZcY1N5Qgqii+BpXSVkntAqm7RJ/nZUFiiqK13ExdqZ9OVP0cA9uwAM4kL+u3KnjMXHL6s9WJ2WNDy8Vo+29+lyPi/Hhde1O7CTlYUiMyp3Ztaz82Ykn8IyMvbATwyeJuRW9kNu1DU/jOfzdScVOtnZuVq3ZfaazeFYpIYtnM87p5iaz4GfTeVor5JCnlbWFr9a92QNi/sXCqTIPR4tv1b2mM/F+w49iFt73YnBvost7tiRLC88RV1LdJLXswC34uIu6hZClhe/XndkxMWL3Sxd1i6NNItdoCGF/h8likyGE5SGEuVmTxcosM3XpEbErDnfw+63FXeILridpNcwswtuym92K28Wcip41S/ozvBDv4MQM9TeKE4BXsT9HXYWRZvhhLJ6hzm68iRfF8bGvSDOclqu4VTS5Ah9hskhRRZL20joW94lTty3iGDxRqqoCyesvAH1DL6x8SuWI4UHnP3VdftB00CrhAAAAAElFTkSuQmCC";

	// UIImages
	UIImage *tab1Img = [UIImage imageWithData:[NSData dataWithContentsOfURL:[NSURL URLWithString:tab1Base64]] scale:2];
	UIImage *tab2Img = [UIImage imageWithData:[NSData dataWithContentsOfURL:[NSURL URLWithString:tab2Base64]] scale:2];
	UIImage *tab3Img = [UIImage imageWithData:[NSData dataWithContentsOfURL:[NSURL URLWithString:tab3Base64]] scale:2];
	UIImage *tab4Img = [UIImage imageWithData:[NSData dataWithContentsOfURL:[NSURL URLWithString:tab4Base64]] scale:2];


	UITabBarItem *tabBarItem1 = [[UITabBarItem alloc] initWithTitle:@"Home" image:tab1Img tag:0];
	UITabBarItem *tabBarItem2 = [[UITabBarItem alloc] initWithTitle:@"Maps" image:tab2Img tag:1];
	UITabBarItem *tabBarItem3 = [[UITabBarItem alloc] initWithTitle:@"Forums" image:tab3Img tag:2];
	UITabBarItem *tabBarItem4 = [[UITabBarItem alloc] initWithTitle:@"Chat" image:tab4Img tag:3];

	[tab.tabBarItem1 setTitleTextAttributes:[NSDictionary dictionaryWithObjectsAndKeys:
	[UIFont fontWithName:@"Helvetica" size:12.0], UITextAttributeFont, nil]
	forState:UIControlStateNormal];

	[tab.tabBarItem2 setTitleTextAttributes:[NSDictionary dictionaryWithObjectsAndKeys:
	[UIFont fontWithName:@"Helvetica" size:12.0], UITextAttributeFont, nil]
	forState:UIControlStateNormal];

	[tab.tabBarItem3 setTitleTextAttributes:[NSDictionary dictionaryWithObjectsAndKeys:
	[UIFont fontWithName:@"Helvetica" size:12.0], UITextAttributeFont, nil]
	forState:UIControlStateNormal];

	[tab.tabBarItem4 setTitleTextAttributes:[NSDictionary dictionaryWithObjectsAndKeys:
	[UIFont fontWithName:@"Helvetica" size:12.0], UITextAttributeFont, nil]
	forState:UIControlStateNormal];

	[tabBarItems addObject:tabBarItem1];
	[tabBarItems addObject:tabBarItem2];
	[tabBarItems addObject:tabBarItem3];
	[tabBarItems addObject:tabBarItem4];

	self.tabBar.items = tabBarItems;
	self.tabBar.selectedItem = [tabBarItems objectAtIndex:0];
	self.tabBar.autoresizesSubviews = YES;
	self.tabBar.userInteractionEnabled = YES;
	self.tabBar.hidden = NO;
	self.tabBar.delegate = self;





	CGFloat labelInset = 5.0;
	float tabBarHeight = TABBAR_HEIGHT;
	if ([[self platform] rangeOfString:@"iPad"].location != NSNotFound) {
		tabBarHeight = 56.0;
	}
	float locationBarY = toolbarIsAtBottom ? self.view.bounds.size.height - (FOOTER_HEIGHT + tabBarHeight) : self.view.bounds.size.height - LOCATIONBAR_HEIGHT;

	self.addressLabel = [[UILabel alloc] initWithFrame:CGRectMake(labelInset, locationBarY, self.view.bounds.size.width - labelInset, LOCATIONBAR_HEIGHT)];
	self.addressLabel.adjustsFontSizeToFitWidth = NO;
	self.addressLabel.alpha = 0.65;
	self.addressLabel.autoresizesSubviews = YES;
	self.addressLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleTopMargin;
	self.addressLabel.backgroundColor = [UIColor clearColor];
	self.addressLabel.baselineAdjustment = UIBaselineAdjustmentAlignCenters;
	self.addressLabel.clearsContextBeforeDrawing = YES;
	self.addressLabel.clipsToBounds = YES;
	self.addressLabel.contentMode = UIViewContentModeScaleToFill;
	self.addressLabel.enabled = YES;
	self.addressLabel.hidden = NO;
	self.addressLabel.lineBreakMode = NSLineBreakByTruncatingTail;

	if ([self.addressLabel respondsToSelector:NSSelectorFromString(@"setMinimumScaleFactor:")]) {
		[self.addressLabel setValue:@(10.0/[UIFont labelFontSize]) forKey:@"minimumScaleFactor"];
	} else if ([self.addressLabel respondsToSelector:NSSelectorFromString(@"setMinimumFontSize:")]) {
		[self.addressLabel setValue:@(10.0) forKey:@"minimumFontSize"];
	}

	self.addressLabel.multipleTouchEnabled = NO;
	self.addressLabel.numberOfLines = 1;
	self.addressLabel.opaque = NO;
	self.addressLabel.shadowOffset = CGSizeMake(0.0, -1.0);
	self.addressLabel.text = NSLocalizedString(@"Loading...", nil);
	self.addressLabel.textAlignment = NSTextAlignmentLeft;
	self.addressLabel.textColor = [UIColor colorWithWhite:1.000 alpha:1.000];
	self.addressLabel.userInteractionEnabled = NO;

	NSString* frontArrowString = NSLocalizedString(@"►", nil); // create arrow from Unicode char
	self.forwardButton = [[UIBarButtonItem alloc] initWithTitle:frontArrowString style:UIBarButtonItemStylePlain target:self action:@selector(goForward:)];
	self.forwardButton.enabled = YES;
	self.forwardButton.imageInsets = UIEdgeInsetsZero;

	NSString* backArrowString = NSLocalizedString(@"◄", nil); // create arrow from Unicode char
	self.backButton = [[UIBarButtonItem alloc] initWithTitle:backArrowString style:UIBarButtonItemStylePlain target:self action:@selector(goBack:)];
	self.backButton.enabled = YES;
	self.backButton.imageInsets = UIEdgeInsetsZero;

	[self.toolbar setItems:@[self.closeButton, flexibleSpaceButton, self.backButton, fixedSpaceButton, self.forwardButton]];

	self.view.backgroundColor = [UIColor colorWithRed:188/255.0f green:79/255.0f blue:68/255.0f alpha:1.0f];
	[self.view addSubview:self.toolbar];

	// TabBar test
	[self.view addSubview:self.tabBar];

	[self.view addSubview:self.addressLabel];
	[self.view addSubview:self.spinner];
}

- (void) setWebViewFrame : (CGRect) frame {
	NSLog(@"Setting the WebView's frame to %@", NSStringFromCGRect(frame));
	[self.webView setFrame:frame];
}

- (void)setCloseButtonTitle:(NSString*)title
{
	// the advantage of using UIBarButtonSystemItemDone is the system will localize it for you automatically
	// but, if you want to set this yourself, knock yourself out (we can't set the title for a system Done button, so we have to create a new one)
	self.closeButton = nil;
	self.closeButton = [[UIBarButtonItem alloc] initWithTitle:title style:UIBarButtonItemStyleBordered target:self action:@selector(close)];
	self.closeButton.enabled = ![title isEqualToString:@""] ? YES : NO; // Don't init if the title is blank
	self.closeButton.tintColor = [UIColor colorWithWhite:1.000 alpha:1.000];

	NSMutableArray* items = [self.toolbar.items mutableCopy];
	[items replaceObjectAtIndex:0 withObject:self.closeButton];
	[self.toolbar setItems:items];
}

- (void)showLocationBar:(BOOL)show
{
	CGRect locationbarFrame = self.addressLabel.frame;

	BOOL toolbarVisible = !self.toolbar.hidden;

	// prevent double show/hide
	if (show == !(self.addressLabel.hidden)) {
		return;
	}

	float tabBarHeight = TABBAR_HEIGHT;
	if ([[self platform] rangeOfString:@"iPad"].location != NSNotFound) {
		tabBarHeight = 56.0;
	}

	if (show) {
		self.addressLabel.hidden = NO;

		if (toolbarVisible) {
			// toolBar at the bottom, leave as is
			// put locationBar on top of the toolBar

			CGRect webViewBounds = self.view.bounds;
			webViewBounds.size.height -= FOOTER_HEIGHT + tabBarHeight;
			[self setWebViewFrame:webViewBounds];

			locationbarFrame.origin.y = webViewBounds.size.height;
			self.addressLabel.frame = locationbarFrame;
		} else {
			// no toolBar, so put locationBar at the bottom

			CGRect webViewBounds = self.view.bounds;
			webViewBounds.size.height -= LOCATIONBAR_HEIGHT + tabBarHeight;
			[self setWebViewFrame:webViewBounds];

			locationbarFrame.origin.y = webViewBounds.size.height;
			self.addressLabel.frame = locationbarFrame;
		}
	} else {
		self.addressLabel.hidden = YES;

		if (toolbarVisible) {
			// locationBar is on top of toolBar, hide locationBar

			// webView take up whole height less toolBar height
			CGRect webViewBounds = self.view.bounds;
			webViewBounds.size.height -= TOOLBAR_HEIGHT + tabBarHeight;
			[self setWebViewFrame:webViewBounds];
		} else {
			// no toolBar, expand webView to screen dimensions
			[self setWebViewFrame:self.view.bounds];
		}
	}
}







// Tab bar testing
- (void)showTabBar:(BOOL)show : (NSNumber *) tabBarInit
{
	if (show == !(self.tabBar.hidden)) {
		self.tabBar.hidden = show ? NO : YES;
	}

	NSInteger index = [tabBarInit integerValue];
    UITabBarItem *item = [self.tabBar.items objectAtIndex:index];

    self.tabBar.selectedItem = item ? item : nil;
}

- (void)tabBar:(UITabBar *)tabBar didSelectItem:(UITabBarItem *)item
{
    //NSString * jsCallBack = [NSString stringWithFormat:@"window.plugins.nativeControls.tabBarItemSelected(%d);", item.tag];    
    //[self.webView stringByEvaluatingJavaScriptFromString:jsCallBack];
    //[self close];
    [self.navigationDelegate toolbarItemTapped:item.tag];
}








- (void)showToolBar:(BOOL)show : (NSString *) toolbarPosition
{
	CGRect toolbarFrame = self.toolbar.frame;
	CGRect locationbarFrame = self.addressLabel.frame;

	BOOL locationbarVisible = !self.addressLabel.hidden;

	// prevent double show/hide
	if (show == !(self.toolbar.hidden)) {
		return;
	}

	if (show) {
		self.toolbar.hidden = NO;
		CGRect webViewBounds = self.view.bounds;

		if (locationbarVisible) {
			// locationBar at the bottom, move locationBar up
			// put toolBar at the bottom
			webViewBounds.size.height -= FOOTER_HEIGHT;
			locationbarFrame.origin.y = webViewBounds.size.height;
			self.addressLabel.frame = locationbarFrame;
			self.toolbar.frame = toolbarFrame;
		} else {
			// no locationBar, so put toolBar at the bottom
			CGRect webViewBounds = self.view.bounds;
			webViewBounds.size.height -= TOOLBAR_HEIGHT;
			self.toolbar.frame = toolbarFrame;
		}

		if ([toolbarPosition isEqualToString:kInAppBrowserToolbarBarPositionTop]) {
			toolbarFrame.origin.y = 0;
			webViewBounds.origin.y += toolbarFrame.size.height;
			[self setWebViewFrame:webViewBounds];
		} else {
			toolbarFrame.origin.y = (webViewBounds.size.height + LOCATIONBAR_HEIGHT);
		}
		[self setWebViewFrame:webViewBounds];

	} else {
		self.toolbar.hidden = YES;

		if (locationbarVisible) {
			// locationBar is on top of toolBar, hide toolBar
			// put locationBar at the bottom

			// webView take up whole height less locationBar height
			CGRect webViewBounds = self.view.bounds;
			webViewBounds.size.height -= LOCATIONBAR_HEIGHT;
			[self setWebViewFrame:webViewBounds];

			// move locationBar down
			locationbarFrame.origin.y = webViewBounds.size.height;
			self.addressLabel.frame = locationbarFrame;
		} else {
			// no locationBar, expand webView to screen dimensions
			[self setWebViewFrame:self.view.bounds];
		}
	}
}

- (void)viewDidLoad
{
	[super viewDidLoad];
}

- (void)viewDidUnload
{
	[self.webView loadHTMLString:nil baseURL:nil];
	[CDVUserAgentUtil releaseLock:&_userAgentLockToken];
	[super viewDidUnload];
}

- (UIStatusBarStyle)preferredStatusBarStyle
{
	//return UIStatusBarStyleDefault;
	return UIStatusBarStyleLightContent;
}

- (void)close
{
	[CDVUserAgentUtil releaseLock:&_userAgentLockToken];
	self.currentURL = nil;

	if ((self.navigationDelegate != nil) && [self.navigationDelegate respondsToSelector:@selector(browserExit)]) {
		[self.navigationDelegate browserExit];
	}

	// Run later to avoid the "took a long time" log message.
	dispatch_async(dispatch_get_main_queue(), ^{
		if ([self respondsToSelector:@selector(presentingViewController)]) {
			[[self presentingViewController] dismissViewControllerAnimated:YES completion:nil];
		} else {
			[[self parentViewController] dismissViewControllerAnimated:YES completion:nil];
		}
	});
}

- (void)hide
{
	[CDVUserAgentUtil releaseLock:&_userAgentLockToken];

	// Run later to avoid the "took a long time" log message.
	dispatch_async(dispatch_get_main_queue(), ^{
		if ([self respondsToSelector:@selector(presentingViewController)]) {
			[[self presentingViewController] dismissViewControllerAnimated:YES completion:nil];
		} else {
			[[self parentViewController] dismissViewControllerAnimated:YES completion:nil];
		}
	});
}

- (void)navigateTo:(NSURL*)url
{
	NSURLRequest* request = [NSURLRequest requestWithURL:url];

	if (_userAgentLockToken != 0) {
		[self.webView loadRequest:request];
	} else {
		[CDVUserAgentUtil acquireLock:^(NSInteger lockToken) {
			_userAgentLockToken = lockToken;
			[CDVUserAgentUtil setUserAgent:_userAgent lockToken:lockToken];
			[self.webView loadRequest:request];
		}];
	}
}

- (void)goBack:(id)sender
{
	[self.webView goBack];
}

- (void)goForward:(id)sender
{
	[self.webView goForward];
}

- (void)viewWillAppear:(BOOL)animated
{
	if (IsAtLeastiOSVersion(@"7.0")) {
		[[UIApplication sharedApplication] setStatusBarStyle:[self preferredStatusBarStyle]];
	}
	[self rePositionViews];

	[super viewWillAppear:animated];
}

//
// On iOS 7 the status bar is part of the view's dimensions, therefore it's height has to be taken into account.
// The height of it could be hardcoded as 20 pixels, but that would assume that the upcoming releases of iOS won't
// change that value.
//
- (float) getStatusBarOffset {
	CGRect statusBarFrame = [[UIApplication sharedApplication] statusBarFrame];
	float statusBarOffset = IsAtLeastiOSVersion(@"7.0") ? MIN(statusBarFrame.size.width, statusBarFrame.size.height) : 0.0;
	return statusBarOffset;
}

- (void) rePositionViews {
	if ([_browserOptions.toolbarposition isEqualToString:kInAppBrowserToolbarBarPositionTop]) {
		[self.webView setFrame:CGRectMake(self.webView.frame.origin.x, TOOLBAR_HEIGHT, self.webView.frame.size.width, self.webView.frame.size.height)];
		[self.toolbar setFrame:CGRectMake(self.toolbar.frame.origin.x, [self getStatusBarOffset], self.toolbar.frame.size.width, self.toolbar.frame.size.height)];
	}
}

#pragma mark UIWebViewDelegate

- (void)webViewDidStartLoad:(UIWebView*)theWebView
{
	// loading url, start spinner, update back/forward

	self.addressLabel.text = NSLocalizedString(@"Loading...", nil);
	self.backButton.enabled = theWebView.canGoBack;
	self.forwardButton.enabled = theWebView.canGoForward;

	[self.spinner startAnimating];

	return [self.navigationDelegate webViewDidStartLoad:theWebView];
}

- (BOOL)webView:(UIWebView*)theWebView shouldStartLoadWithRequest:(NSURLRequest*)request navigationType:(UIWebViewNavigationType)navigationType
{
	BOOL isTopLevelNavigation = [request.URL isEqual:[request mainDocumentURL]];

	if (isTopLevelNavigation) {
		self.currentURL = request.URL;
	}
	return [self.navigationDelegate webView:theWebView shouldStartLoadWithRequest:request navigationType:navigationType];
}

- (void)webViewDidFinishLoad:(UIWebView*)theWebView
{
	// update url, stop spinner, update back/forward

	//self.addressLabel.text = [self.currentURL absoluteString];
	self.addressLabel.text = NSLocalizedString(@"Loaded", nil);
	self.backButton.enabled = theWebView.canGoBack;
	self.forwardButton.enabled = theWebView.canGoForward;

	[self.spinner stopAnimating];

	// Work around a bug where the first time a PDF is opened, all UIWebViews
	// reload their User-Agent from NSUserDefaults.
	// This work-around makes the following assumptions:
	// 1. The app has only a single Cordova Webview. If not, then the app should
	//    take it upon themselves to load a PDF in the background as a part of
	//    their start-up flow.
	// 2. That the PDF does not require any additional network requests. We change
	//    the user-agent here back to that of the CDVViewController, so requests
	//    from it must pass through its white-list. This *does* break PDFs that
	//    contain links to other remote PDF/websites.
	// More info at https://issues.apache.org/jira/browse/CB-2225
	BOOL isPDF = [@"true" isEqualToString :[theWebView stringByEvaluatingJavaScriptFromString:@"document.body==null"]];
	if (isPDF) {
		[CDVUserAgentUtil setUserAgent:_prevUserAgent lockToken:_userAgentLockToken];
	}

	[self.navigationDelegate webViewDidFinishLoad:theWebView];
}

- (void)webView:(UIWebView*)theWebView didFailLoadWithError:(NSError*)error
{
	// log fail message, stop spinner, update back/forward
	NSLog(@"webView:didFailLoadWithError - %ld: %@", (long)error.code, [error localizedDescription]);

	self.backButton.enabled = theWebView.canGoBack;
	self.forwardButton.enabled = theWebView.canGoForward;
	[self.spinner stopAnimating];

	self.addressLabel.text = NSLocalizedString(@"Load Error", nil);

	[self.navigationDelegate webView:theWebView didFailLoadWithError:error];
}

#pragma mark CDVScreenOrientationDelegate

- (BOOL)shouldAutorotate
{
	if ((self.orientationDelegate != nil) && [self.orientationDelegate respondsToSelector:@selector(shouldAutorotate)]) {
		return [self.orientationDelegate shouldAutorotate];
	}
	return YES;
}

- (NSUInteger)supportedInterfaceOrientations
{
	if ((self.orientationDelegate != nil) && [self.orientationDelegate respondsToSelector:@selector(supportedInterfaceOrientations)]) {
		return [self.orientationDelegate supportedInterfaceOrientations];
	}

	return 1 << UIInterfaceOrientationPortrait;
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
	if ((self.orientationDelegate != nil) && [self.orientationDelegate respondsToSelector:@selector(shouldAutorotateToInterfaceOrientation:)]) {
		return [self.orientationDelegate shouldAutorotateToInterfaceOrientation:interfaceOrientation];
	}

	return YES;
}

@end

@implementation CDVInAppBrowserBetaOptions

- (id)init
{
	if (self = [super init]) {
		// default values
		self.location = YES;
		self.toolbar = YES;
		self.tabbar = YES;
		self.tabbarinit = 0;
		self.closebuttoncaption = nil;
		self.toolbarposition = kInAppBrowserToolbarBarPositionBottom;
		self.clearcache = NO;
		self.clearsessioncache = NO;

		self.enableviewportscale = NO;
		self.mediaplaybackrequiresuseraction = NO;
		self.allowinlinemediaplayback = NO;
		self.keyboarddisplayrequiresuseraction = YES;
		self.suppressesincrementalrendering = NO;
		self.hidden = NO;
		self.disallowoverscroll = NO;
	}

	return self;
}

+ (CDVInAppBrowserBetaOptions*)parseOptions:(NSString*)options
{
	CDVInAppBrowserBetaOptions* obj = [[CDVInAppBrowserBetaOptions alloc] init];

	// NOTE: this parsing does not handle quotes within values
	NSArray* pairs = [options componentsSeparatedByString:@","];

	// parse keys and values, set the properties
	for (NSString* pair in pairs) {
		NSArray* keyvalue = [pair componentsSeparatedByString:@"="];

		if ([keyvalue count] == 2) {
			NSString* key = [[keyvalue objectAtIndex:0] lowercaseString];
			NSString* value = [keyvalue objectAtIndex:1];
			NSString* value_lc = [value lowercaseString];

			BOOL isBoolean = [value_lc isEqualToString:@"yes"] || [value_lc isEqualToString:@"no"];
			NSNumberFormatter* numberFormatter = [[NSNumberFormatter alloc] init];
			[numberFormatter setAllowsFloats:YES];
			BOOL isNumber = [numberFormatter numberFromString:value_lc] != nil;

			// set the property according to the key name
			if ([obj respondsToSelector:NSSelectorFromString(key)]) {
				if (isNumber) {
					[obj setValue:[numberFormatter numberFromString:value_lc] forKey:key];
				} else if (isBoolean) {
					[obj setValue:[NSNumber numberWithBool:[value_lc isEqualToString:@"yes"]] forKey:key];
				} else {
					[obj setValue:value forKey:key];
				}
			}
		}
	}

	return obj;
}

@end

@implementation CDVInAppBrowserBetaNavigationController : UINavigationController

#pragma mark CDVScreenOrientationDelegate

- (BOOL)shouldAutorotate
{
	if ((self.orientationDelegate != nil) && [self.orientationDelegate respondsToSelector:@selector(shouldAutorotate)]) {
		return [self.orientationDelegate shouldAutorotate];
	}
	return YES;
}

- (NSUInteger)supportedInterfaceOrientations
{
	if ((self.orientationDelegate != nil) && [self.orientationDelegate respondsToSelector:@selector(supportedInterfaceOrientations)]) {
		return [self.orientationDelegate supportedInterfaceOrientations];
	}

	return 1 << UIInterfaceOrientationPortrait;
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
	if ((self.orientationDelegate != nil) && [self.orientationDelegate respondsToSelector:@selector(shouldAutorotateToInterfaceOrientation:)]) {
		return [self.orientationDelegate shouldAutorotateToInterfaceOrientation:interfaceOrientation];
	}

	return YES;
}


@end


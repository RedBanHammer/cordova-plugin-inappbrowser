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
package org.apache.cordova.inappbrowserbeta;

import android.annotation.SuppressLint;
import org.apache.cordova.inappbrowserbeta.InAppBrowserBetaDialog;
import android.content.Context;
import android.content.Intent;
import android.content.res.Resources;
import android.graphics.Bitmap;
import android.graphics.drawable.Drawable;
import android.net.Uri;
import android.os.Build;
import android.os.Bundle;
import android.text.InputType;
import android.util.Log;
import android.util.TypedValue;
import android.view.Gravity;
import android.view.KeyEvent;
import android.view.View;
import android.view.Window;
import android.view.WindowManager;
import android.view.WindowManager.LayoutParams;
import android.view.inputmethod.EditorInfo;
import android.view.inputmethod.InputMethodManager;
import android.webkit.JavascriptInterface;
import android.webkit.CookieManager;
import android.webkit.WebSettings;
import android.webkit.WebView;
import android.webkit.WebViewClient;
import android.widget.Button;
import android.widget.EditText;
import android.widget.LinearLayout;
import android.widget.RelativeLayout;

import android.app.ActionBar;
import android.app.ActionBar.Tab;
import android.app.Activity;
import android.support.v4.app.Fragment;
import android.app.FragmentManager;
import android.app.FragmentTransaction;
import android.graphics.drawable.ColorDrawable;
import android.view.LayoutInflater;
import android.view.ViewGroup;
import android.R;

import org.apache.cordova.CallbackContext;
import org.apache.cordova.Config;
import org.apache.cordova.CordovaArgs;
import org.apache.cordova.CordovaPlugin;
import org.apache.cordova.CordovaWebView;
import org.apache.cordova.LOG;
import org.apache.cordova.PluginResult;
import org.json.JSONException;
import org.json.JSONObject;

import java.util.HashMap;
import java.util.StringTokenizer;

@SuppressLint("SetJavaScriptEnabled")
public class InAppBrowserBeta extends CordovaPlugin {

    private static final String NULL = "null";
    protected static final String LOG_TAG = "InAppBrowserBeta";
    private static final String SELF = "_self";
    private static final String SYSTEM = "_system";
    // private static final String BLANK = "_blank";
    private static final String EXIT_EVENT = "exit";
    private static final String LOCATION = "location";
    private static final String HIDDEN = "hidden";
    private static final String LOAD_START_EVENT = "loadstart";
    private static final String LOAD_STOP_EVENT = "loadstop";
    private static final String LOAD_ERROR_EVENT = "loaderror";
    private static final String CLOSE_BUTTON_CAPTION = "closebuttoncaption";
    private static final String CLEAR_ALL_CACHE = "clearcache";
    private static final String CLEAR_SESSION_CACHE = "clearsessioncache";

    private InAppBrowserBetaDialog dialog;
    private WebView inAppWebView;
    private EditText edittext;
    private CallbackContext callbackContext;
    private boolean showLocationBar = true;
    private boolean openWindowHidden = false;
    private String buttonLabel = "Done";
    private boolean clearAllCache= false;
    private boolean clearSessionCache=false;
    private boolean showTabBar = true;
    private int tabBarInit = 0;

    public class LoadedStatusInterface {
        @JavascriptInterface
        @SuppressWarnings("unused")
        public void callback(String s) {
            try {
                JSONObject obj = new JSONObject();
                obj.put("type", "loadedStatus");
                obj.put("loaded", s);

                //if (s != "false" && inAppWebView != null) inAppWebView.invalidate();
    
                sendUpdate(obj, true);
            } catch (JSONException ex) {
                Log.d(LOG_TAG, "Should never happen");
            }
        }
    }

    public class NotifyStatusInterface {
        @JavascriptInterface
        @SuppressWarnings("unused")
        public void callback(String s) {
            try {
                JSONObject obj = new JSONObject();
                obj.put("type", "notifyStatus");
                obj.put("notify", s);

                //if (s != "false" && inAppWebView != null) inAppWebView.invalidate();
    
                sendUpdate(obj, true);
            } catch (JSONException ex) {
                Log.d(LOG_TAG, "Should never happen");
            }
        }
    }

    /**
     * Executes the request and returns PluginResult.
     *
     * @param action        The action to execute.
     * @param args          JSONArry of arguments for the plugin.
     * @param callbackId    The callback id used when calling back into JavaScript.
     * @return              A PluginResult object with a status and message.
     */
    public boolean execute(String action, CordovaArgs args, final CallbackContext callbackContext) throws JSONException {
        if (action.equals("open")) {
            this.callbackContext = callbackContext;
            final String url = args.getString(0);
            String t = args.optString(1);
            if (t == null || t.equals("") || t.equals(NULL)) {
                t = SELF;
            }
            final String target = t;
            final HashMap<String, Boolean> features = parseFeature(args.optString(2));
            
            Log.d(LOG_TAG, "target = " + target);
            
            this.cordova.getActivity().runOnUiThread(new Runnable() {
                @Override
                public void run() {
                    String result = "";
                    // SELF
                    if (SELF.equals(target)) {
                        Log.d(LOG_TAG, "in self");
                        // load in webview
                        if (url.startsWith("file://") || url.startsWith("javascript:") 
                                || Config.isUrlWhiteListed(url)) {
                            webView.loadUrl(url);
                        }
                        //Load the dialer
                        else if (url.startsWith(WebView.SCHEME_TEL))
                        {
                            try {
                                Intent intent = new Intent(Intent.ACTION_DIAL);
                                intent.setData(Uri.parse(url));
                               cordova.getActivity().startActivity(intent);
                            } catch (android.content.ActivityNotFoundException e) {
                                LOG.e(LOG_TAG, "Error dialing " + url + ": " + e.toString());
                            }
                        }
                        // load in InAppBrowser
                        else {
                            result = showWebPage(url, features);
                        }
                    }
                    // SYSTEM
                    else if (SYSTEM.equals(target)) {
                        Log.d(LOG_TAG, "in system");
                        result = openExternal(url);
                    }
                    // BLANK - or anything else
                    else {
                        Log.d(LOG_TAG, "in blank");
                        result = showWebPage(url, features);
                    }
    
                    PluginResult pluginResult = new PluginResult(PluginResult.Status.OK, result);
                    pluginResult.setKeepCallback(true);
                    callbackContext.sendPluginResult(pluginResult);
                }
            });
        }
        else if (action.equals("close")) {
            closeDialog();
        }
        else if (action.equals("injectScriptCode")) {
            String jsWrapper = null;
            if (args.getBoolean(1)) {
                jsWrapper = String.format("prompt(JSON.stringify([eval(%%s)]), 'gap-iab://%s')", callbackContext.getCallbackId());
            }
            injectDeferredObject(args.getString(0), jsWrapper);
        }
        else if (action.equals("injectScriptFile")) {
            String jsWrapper;
            if (args.getBoolean(1)) {
                jsWrapper = String.format("(function(d) { var c = d.createElement('script'); c.src = %%s; c.onload = function() { prompt('', 'gap-iab://%s'); }; d.body.appendChild(c); })(document)", callbackContext.getCallbackId());
            } else {
                jsWrapper = "(function(d) { var c = d.createElement('script'); c.src = %s; d.body.appendChild(c); })(document)";
            }
            injectDeferredObject(args.getString(0), jsWrapper);
        }
        else if (action.equals("injectStyleCode")) {
            String jsWrapper;
            if (args.getBoolean(1)) {
                jsWrapper = String.format("(function(d) { var c = d.createElement('style'); c.innerHTML = %%s; d.body.appendChild(c); prompt('', 'gap-iab://%s');})(document)", callbackContext.getCallbackId());
            } else {
                jsWrapper = "(function(d) { var c = d.createElement('style'); c.innerHTML = %s; d.body.appendChild(c); })(document)";
            }
            injectDeferredObject(args.getString(0), jsWrapper);
        }
        else if (action.equals("injectStyleFile")) {
            String jsWrapper;
            if (args.getBoolean(1)) {
                jsWrapper = String.format("(function(d) { var c = d.createElement('link'); c.rel='stylesheet'; c.type='text/css'; c.href = %%s; d.head.appendChild(c); prompt('', 'gap-iab://%s');})(document)", callbackContext.getCallbackId());
            } else {
                jsWrapper = "(function(d) { var c = d.createElement('link'); c.rel='stylesheet'; c.type='text/css'; c.href = %s; d.head.appendChild(c); })(document)";
            }
            injectDeferredObject(args.getString(0), jsWrapper);
        }
        else if (action.equals("show")) {
            this.cordova.getActivity().runOnUiThread(new Runnable() {
                @Override
                public void run() {
                    dialog.show();
                    //dialog.setVisibility(View.VISIBLE);
                }
            });
            PluginResult pluginResult = new PluginResult(PluginResult.Status.OK);
            pluginResult.setKeepCallback(true);
            this.callbackContext.sendPluginResult(pluginResult);
        }
        else if (action.equals("loadedStatus")) {
            this.cordova.getActivity().runOnUiThread(new Runnable() {
                @Override
                public void run() {
                    inAppWebView.addJavascriptInterface(new LoadedStatusInterface(), "LOADEDSTATUS");
                    addCallbackInterface(inAppWebView);
                    //inAppWebView.loadUrl("javascript:setTimeout(function() { try { var s = document.getElementById('shotbowAppPageLoaded').getAttribute('token').toString(); console.log('~$~$~$~$~$~Sending loadedStatus callback: ' + s); window.LOADEDSTATUS.callback(s); } catch(e) { console.log('$$$$$$$$ERROR TRYING TO EXEC LOADEDSTATUS CALLBACK: ' + e.message); } }, 100);");
                    inAppWebView.loadUrl("javascript:setTimeout(function() { try { var s = document.getElementById('shotbowAppPageLoaded').getAttribute('token').toString(); window.LOADEDSTATUS.callback(s); } catch(e) { } }, 100);");
                }
            });
        }
        else if (action.equals("notifyStatus")) {
            this.cordova.getActivity().runOnUiThread(new Runnable() {
                @Override
                public void run() {
                    inAppWebView.addJavascriptInterface(new NotifyStatusInterface(), "NOTIFYSTATUS");
                    addCallbackInterfaceNotify(inAppWebView);
                    //inAppWebView.loadUrl("javascript:if (typeof shotbowAppNotifyStatusInterval !== 'undefined') { clearInterval(shotbowAppNotifyStatusInterval); } shotbowAppNotifyStatusInterval = setInterval(function() { try { var s = (typeof shotbowAppNotify !== 'undefined' ? shotbowAppNotify : false).toString(); shotbowAppNotify = false; console.log('~$~$~$~$~$~Sending notifyStatus callback: ' + s); window.NOTIFYSTATUS.callback(s); } catch(e) { console.log('$$$$$$$$ERROR TRYING TO EXEC NOTIFYSTATUS CALLBACK: ' + e.message); } }, 1000);");
                    inAppWebView.loadUrl("javascript:if (typeof shotbowAppNotifyStatusInterval !== 'undefined') { clearInterval(shotbowAppNotifyStatusInterval); } shotbowAppNotifyStatusInterval = setInterval(function() { try { var s = (typeof shotbowAppNotify !== 'undefined' ? shotbowAppNotify : false).toString(); shotbowAppNotify = false; window.NOTIFYSTATUS.callback(s); } catch(e) { } }, 1000);");
                }
            });
        } else if (action.equals("hide")) {
            hideDialog();
        }
        else {
            return false;
        }
        return true;
    }

    /**
     * Called when the view navigates.
     */
    @Override
    public void onReset() {
        closeDialog();        
    }
    
    /**
     * Called by AccelBroker when listener is to be shut down.
     * Stop listener.
     */
    public void onDestroy() {
        closeDialog();
    }
    
    /**
     * Inject an object (script or style) into the InAppBrowser WebView.
     *
     * This is a helper method for the inject{Script|Style}{Code|File} API calls, which
     * provides a consistent method for injecting JavaScript code into the document.
     *
     * If a wrapper string is supplied, then the source string will be JSON-encoded (adding
     * quotes) and wrapped using string formatting. (The wrapper string should have a single
     * '%s' marker)
     *
     * @param source      The source object (filename or script/style text) to inject into
     *                    the document.
     * @param jsWrapper   A JavaScript string to wrap the source string in, so that the object
     *                    is properly injected, or null if the source string is JavaScript text
     *                    which should be executed directly.
     */
    private void injectDeferredObject(String source, String jsWrapper) {
        String scriptToInject;
        if (jsWrapper != null) {
            org.json.JSONArray jsonEsc = new org.json.JSONArray();
            jsonEsc.put(source);
            String jsonRepr = jsonEsc.toString();
            String jsonSourceString = jsonRepr.substring(1, jsonRepr.length()-1);
            scriptToInject = String.format(jsWrapper, jsonSourceString);
        } else {
            scriptToInject = source;
        }
        final String finalScriptToInject = scriptToInject;
        this.cordova.getActivity().runOnUiThread(new Runnable() {
            @SuppressLint("NewApi")
            @Override
            public void run() {
                //if (Build.VERSION.SDK_INT < Build.VERSION_CODES.KITKAT) {
                // Appgyver throws an error with the edge legacy build if using reference
                //if (Build.VERSION.SDK_INT < 19) {
                    // This action will have the side-effect of blurring the currently focused element
                if (inAppWebView != null && finalScriptToInject != null) inAppWebView.loadUrl("javascript:" + finalScriptToInject);
                //} else {// More appgyver errors
                    //inAppWebView.evaluateJavascript(finalScriptToInject, null);
                //}
            }
        });
    }

    /**
     * Put the list of features into a hash map
     * 
     * @param optString
     * @return
     */
    private HashMap<String, Boolean> parseFeature(String optString) {
        if (optString.equals(NULL)) {
            return null;
        } else {
            HashMap<String, Boolean> map = new HashMap<String, Boolean>();
            StringTokenizer features = new StringTokenizer(optString, ",");
            StringTokenizer option;
            while(features.hasMoreElements()) {
                option = new StringTokenizer(features.nextToken(), "=");
                if (option.hasMoreElements()) {
                    String key = option.nextToken();
                    if (key.equalsIgnoreCase(CLOSE_BUTTON_CAPTION)) {
                        this.buttonLabel = option.nextToken();
                    } else {
                        Boolean value = option.nextToken().equals("no") ? Boolean.FALSE : Boolean.TRUE;
                        map.put(key, value);
                    }
                }
            }
            return map;
        }
    }

    /**
     * Display a new browser with the specified URL.
     *
     * @param url           The url to load.
     * @param usePhoneGap   Load url in PhoneGap webview
     * @return              "" if ok, or error message.
     */
    public String openExternal(String url) {
        try {
            Intent intent = null;
            intent = new Intent(Intent.ACTION_VIEW);
            // Omitting the MIME type for file: URLs causes "No Activity found to handle Intent".
            // Adding the MIME type to http: URLs causes them to not be handled by the downloader.
            Uri uri = Uri.parse(url);
            if ("file".equals(uri.getScheme())) {
                intent.setDataAndType(uri, webView.getResourceApi().getMimeType(uri));
            } else {
                intent.setData(uri);
            }
            this.cordova.getActivity().startActivity(intent);
            return "";
        } catch (android.content.ActivityNotFoundException e) {
            Log.d(LOG_TAG, "InAppBrowser: Error loading url "+url+":"+ e.toString());
            return e.toString();
        }
    }

    /**
     * Hides the dialog but does NOT dismiss it
     */
    public void hideDialog() {
        this.cordova.getActivity().runOnUiThread(new Runnable() {
            @Override
            public void run() {
                if (dialog != null) dialog.hide();
            }
        });
    }

    /**
     * Closes the dialog
     */
    public void closeDialog() {
        final WebView childView = this.inAppWebView;
        // The JS protects against multiple calls, so this should happen only when
        // closeDialog() is called by other native code.
        if (childView == null) {
            return;
        }

        this.cordova.getActivity().runOnUiThread(new Runnable() {
            @Override
            public void run() {
                childView.setWebViewClient(new WebViewClient() {
                    // NB: wait for about:blank before dismissing
                    public void onPageFinished(WebView view, String url) {
                        if (dialog != null) {
                            dialog.dismiss();
                        }
                    }
                });

                //dialog.dismiss();
                //handler.sendEmptyMessage(0);

                // NB: From SDK 19: "If you call methods on WebView from any thread 
                // other than your app's UI thread, it can cause unexpected results."
                // http://developer.android.com/guide/webapps/migrating.html#Threads
                childView.loadUrl("about:blank");
            }
        });

        try {
            JSONObject obj = new JSONObject();
            obj.put("type", EXIT_EVENT);
            sendUpdate(obj, false);
        } catch (JSONException ex) {
            Log.d(LOG_TAG, "Should never happen");
        }
    }

    /**
     * Checks to see if it is possible to go back one page in history, then does so.
     */
    private void goBack() {
        if (this.inAppWebView.canGoBack()) {
            this.inAppWebView.goBack();
        }
    }

    /**
     * Checks to see if it is possible to go forward one page in history, then does so.
     */
    private void goForward() {
        if (this.inAppWebView.canGoForward()) {
            this.inAppWebView.goForward();
        }
    }

    /**
     * Navigate to the new page
     *
     * @param url to load
     */
    private void navigate(String url) {
        InputMethodManager imm = (InputMethodManager)this.cordova.getActivity().getSystemService(Context.INPUT_METHOD_SERVICE);
        imm.hideSoftInputFromWindow(edittext.getWindowToken(), 0);

        if (!url.startsWith("http") && !url.startsWith("file:")) {
            this.inAppWebView.loadUrl("http://" + url);
        } else {
            this.inAppWebView.loadUrl(url);
        }
        this.inAppWebView.requestFocus();
    }


    /**
     * Should we show the location bar?
     *
     * @return boolean
     */
    private boolean getShowLocationBar() {
        return this.showLocationBar;
    }

    private boolean getShowTabBar() {
        return false;
        //return this.showTabBar;
    }

    private int getTabBarInit() {
        return this.tabBarInit;
    }

    private InAppBrowserBeta getInAppBrowser(){
        return this;
    }

    /**
     * Display a new browser with the specified URL.
     *
     * @param url           The url to load.
     * @param jsonObject
     */
    public String showWebPage(final String url, HashMap<String, Boolean> features) {
        // Determine if we should hide the location bar.
        showLocationBar = true;
        openWindowHidden = false;
        if (features != null) {
            Boolean show = features.get(LOCATION);
            if (show != null) {
                showLocationBar = show.booleanValue();
            }
            Boolean hidden = features.get(HIDDEN);
            if (hidden != null) {
                openWindowHidden = hidden.booleanValue();
            }
            /*Boolean tabbar = features.get("tabbar");
            if (tabbar != null) {
                showTabBar = tabbar.booleanValue();
            }
            int tabbarinit = features.get("tabbarinit");
            if (tabbarinit != null) {
                tabBarInit = tabbarinit;
            }*/
            Boolean cache = features.get(CLEAR_ALL_CACHE);
            if (cache != null) {
                clearAllCache = cache.booleanValue();
            } else {
                cache = features.get(CLEAR_SESSION_CACHE);
                if (cache != null) {
                    clearSessionCache = cache.booleanValue();
                }
            }
        }
        
        final CordovaWebView thatWebView = this.webView;

        // Create dialog in new thread
        Runnable runnable = new Runnable() {
            /**
             * Convert our DIP units to Pixels
             *
             * @return int
             */
            private int dpToPixels(int dipValue) {
                int value = (int) TypedValue.applyDimension( TypedValue.COMPLEX_UNIT_DIP,
                                                            (float) dipValue,
                                                            cordova.getActivity().getResources().getDisplayMetrics()
                );

                return value;
            }

            public void run() {
                // Let's create the main dialog
                dialog = new InAppBrowserBetaDialog(cordova.getActivity(), getShowTabBar() ? android.R.style.Theme_DeviceDefault : android.R.style.Theme_NoTitleBar);
                
                if (getShowTabBar()) dialog.getWindow().requestFeature(Window.FEATURE_ACTION_BAR);

                dialog.getWindow().getAttributes().windowAnimations = android.R.style.Animation_Dialog;
                dialog.requestWindowFeature(getShowTabBar() ? Window.FEATURE_ACTION_BAR : Window.FEATURE_NO_TITLE);
                dialog.setCancelable(true);
                dialog.setInAppBroswer(getInAppBrowser());


                // Main container layout
                LinearLayout main = new LinearLayout(cordova.getActivity());
                main.setOrientation(LinearLayout.VERTICAL);

                // Toolbar layout
                RelativeLayout toolbar = new RelativeLayout(cordova.getActivity());
                //Please, no more black! 
                //toolbar.setBackgroundColor(android.graphics.Color.LTGRAY);
                // How about red?
                toolbar.setBackgroundColor(android.graphics.Color.rgb(188, 79, 68));
                toolbar.setLayoutParams(new RelativeLayout.LayoutParams(LayoutParams.MATCH_PARENT, this.dpToPixels(44)));
                toolbar.setPadding(this.dpToPixels(2), this.dpToPixels(2), this.dpToPixels(2), this.dpToPixels(2));
                toolbar.setHorizontalGravity(Gravity.LEFT);
                toolbar.setVerticalGravity(Gravity.TOP);

                // Action Button Container layout
                RelativeLayout actionButtonContainer = new RelativeLayout(cordova.getActivity());
                actionButtonContainer.setLayoutParams(new RelativeLayout.LayoutParams(LayoutParams.WRAP_CONTENT, LayoutParams.WRAP_CONTENT));
                actionButtonContainer.setHorizontalGravity(Gravity.LEFT);
                actionButtonContainer.setVerticalGravity(Gravity.CENTER_VERTICAL);
                actionButtonContainer.setId(1);

                // Back button
                Button back = new Button(cordova.getActivity());
                RelativeLayout.LayoutParams backLayoutParams = new RelativeLayout.LayoutParams(LayoutParams.WRAP_CONTENT, LayoutParams.MATCH_PARENT);
                backLayoutParams.addRule(RelativeLayout.ALIGN_LEFT);
                back.setLayoutParams(backLayoutParams);
                back.setContentDescription("Back Button");
                back.setId(2);
                /*
                back.setText("<");
                */
                Resources activityRes = cordova.getActivity().getResources();
                int backResId = activityRes.getIdentifier("ic_action_previous_item", "drawable", cordova.getActivity().getPackageName());
                Drawable backIcon = activityRes.getDrawable(backResId);
                if(android.os.Build.VERSION.SDK_INT < android.os.Build.VERSION_CODES.JELLY_BEAN)
                {
                    back.setBackgroundDrawable(backIcon);
                }
                else
                {
                    back.setBackground(backIcon);
                }
                back.setOnClickListener(new View.OnClickListener() {
                    public void onClick(View v) {
                        goBack();
                    }
                });

                // Forward button
                Button forward = new Button(cordova.getActivity());
                RelativeLayout.LayoutParams forwardLayoutParams = new RelativeLayout.LayoutParams(LayoutParams.WRAP_CONTENT, LayoutParams.MATCH_PARENT);
                forwardLayoutParams.addRule(RelativeLayout.RIGHT_OF, 2);
                forward.setLayoutParams(forwardLayoutParams);
                forward.setContentDescription("Forward Button");
                forward.setId(3);
                //forward.setText(">");
                int fwdResId = activityRes.getIdentifier("ic_action_next_item", "drawable", cordova.getActivity().getPackageName());
                Drawable fwdIcon = activityRes.getDrawable(fwdResId);
                if(android.os.Build.VERSION.SDK_INT < android.os.Build.VERSION_CODES.JELLY_BEAN)
                {
                    forward.setBackgroundDrawable(fwdIcon);
                }
                else
                {
                    forward.setBackground(fwdIcon);
                }
                forward.setOnClickListener(new View.OnClickListener() {
                    public void onClick(View v) {
                        goForward();
                    }
                });

                // Edit Text Box
                edittext = new EditText(cordova.getActivity());
                RelativeLayout.LayoutParams textLayoutParams = new RelativeLayout.LayoutParams(LayoutParams.MATCH_PARENT, LayoutParams.MATCH_PARENT);
                textLayoutParams.addRule(RelativeLayout.RIGHT_OF, 1);
                textLayoutParams.addRule(RelativeLayout.LEFT_OF, 5);
                edittext.setLayoutParams(textLayoutParams);
                edittext.setId(4);
                edittext.setSingleLine(true);
                edittext.setText(url);
                edittext.setVisibility(View.GONE);
                edittext.setInputType(InputType.TYPE_TEXT_VARIATION_URI);
                edittext.setImeOptions(EditorInfo.IME_ACTION_GO);
                edittext.setInputType(InputType.TYPE_NULL); // Will not except input... Makes the text NON-EDITABLE
                edittext.setOnKeyListener(new View.OnKeyListener() {
                    public boolean onKey(View v, int keyCode, KeyEvent event) {
                        // If the event is a key-down event on the "enter" button
                        if ((event.getAction() == KeyEvent.ACTION_DOWN) && (keyCode == KeyEvent.KEYCODE_ENTER)) {
                          navigate(edittext.getText().toString());
                          return true;
                        }
                        return false;
                    }
                });

                // Close button
                Button close = new Button(cordova.getActivity());
                RelativeLayout.LayoutParams closeLayoutParams = new RelativeLayout.LayoutParams(LayoutParams.WRAP_CONTENT, LayoutParams.MATCH_PARENT);
                closeLayoutParams.addRule(RelativeLayout.ALIGN_PARENT_RIGHT);
                close.setLayoutParams(closeLayoutParams);
                forward.setContentDescription("Close Button");
                close.setId(5);
                //close.setText(buttonLabel);
                int closeResId = activityRes.getIdentifier("ic_action_remove", "drawable", cordova.getActivity().getPackageName());
                Drawable closeIcon = activityRes.getDrawable(closeResId);
                if(android.os.Build.VERSION.SDK_INT < android.os.Build.VERSION_CODES.JELLY_BEAN)
                {
                    close.setBackgroundDrawable(closeIcon);
                }
                else
                {
                    close.setBackground(closeIcon);
                }
                close.setOnClickListener(new View.OnClickListener() {
                    public void onClick(View v) {
                        closeDialog();
                    }
                });

                // WebView
                inAppWebView = new WebView(cordova.getActivity());
                inAppWebView.setLayoutParams(new LinearLayout.LayoutParams(LayoutParams.MATCH_PARENT, LayoutParams.MATCH_PARENT));
                inAppWebView.setWebChromeClient(new InAppChromeClientBeta(thatWebView));
                WebViewClient client = new InAppBrowserBetaClient(thatWebView, edittext);
                inAppWebView.setWebViewClient(client);
                WebSettings settings = inAppWebView.getSettings();
                settings.setJavaScriptEnabled(true);
                settings.setJavaScriptCanOpenWindowsAutomatically(true);
                settings.setBuiltInZoomControls(true);
                settings.setPluginState(android.webkit.WebSettings.PluginState.ON);

                //Toggle whether this is enabled or not!
                Bundle appSettings = cordova.getActivity().getIntent().getExtras();
                boolean enableDatabase = appSettings == null ? true : appSettings.getBoolean("InAppBrowserStorageEnabled", true);
                if (enableDatabase) {
                    String databasePath = cordova.getActivity().getApplicationContext().getDir("inAppBrowserDB", Context.MODE_PRIVATE).getPath();
                    settings.setDatabasePath(databasePath);
                    settings.setDatabaseEnabled(true);
                }
                settings.setDomStorageEnabled(true);

                if (clearAllCache) {
                    CookieManager.getInstance().removeAllCookie();
                } else if (clearSessionCache) {
                    CookieManager.getInstance().removeSessionCookie();
                }

                inAppWebView.loadUrl(url);
                inAppWebView.setId(6);
                inAppWebView.getSettings().setLoadWithOverviewMode(true);
                inAppWebView.getSettings().setUseWideViewPort(true);
                inAppWebView.requestFocus();
                inAppWebView.requestFocusFromTouch();

                // Add the back and forward buttons to our action button container layout
                actionButtonContainer.addView(back);
                actionButtonContainer.addView(forward);

                // Add the views to our toolbar
                toolbar.addView(actionButtonContainer);
                toolbar.addView(edittext);
                toolbar.addView(close);

                // Don't add the toolbar if its been disabled
                if (getShowLocationBar()) {
                    // Add our toolbar to our main view/layout
                    main.addView(toolbar);
                }

                // Add our webview to our main view/layout
                main.addView(inAppWebView);

                WindowManager.LayoutParams lp = new WindowManager.LayoutParams();

                lp.copyFrom(dialog.getWindow().getAttributes());
                lp.width = WindowManager.LayoutParams.MATCH_PARENT;
                lp.height = WindowManager.LayoutParams.MATCH_PARENT;

                dialog.setContentView(main);
                dialog.show();
                dialog.getWindow().setAttributes(lp);
                //dialog.getWindow().setFlags(WindowManager.LayoutParams.FLAG_HARDWARE_ACCELERATED, WindowManager.LayoutParams.FLAG_HARDWARE_ACCELERATED);
                // the goal of openhidden is to load the url and not display it
                // Show() needs to be called to cause the URL to be loaded
                if(openWindowHidden) {
                	dialog.hide();
                }





                // Action bar testing (fake tabs, etc)
                if (getShowTabBar()) {
                    ActionBar actionBar = dialog.getActionBar();
                    actionBar.setNavigationMode(ActionBar.NAVIGATION_MODE_TABS);
                    actionBar.setBackgroundDrawable(new ColorDrawable(0xffbc4f44));

                    ActionBar.TabListener tabListener = new ActionBar.TabListener() {
                         public void onTabSelected(Tab tab, FragmentTransaction ft) {
                            int tabIndex = tab.getPosition();

                            try {
                                JSONObject obj = new JSONObject();
                                obj.put("type", "toolbarItemTapped");
                                obj.put("index", tabIndex);

                                sendUpdate(obj, true);
                            } catch (JSONException ex) {
                                Log.d(LOG_TAG, "Should never happen");
                            }
                         }

                         public void onTabUnselected(Tab tab, FragmentTransaction ft) {
                             // TODO Auto-generated method stub
                         }

                         public void onTabReselected(Tab tab, FragmentTransaction ft) {
                             // TODO Auto-generated method stub
                         }
                     };

                    ActionBar.Tab tab1 = actionBar.newTab().setText("Home").setTabListener(tabListener);
                    ActionBar.Tab tab2 = actionBar.newTab().setText("Maps").setTabListener(tabListener);
                    ActionBar.Tab tab3 = actionBar.newTab().setText("Forums").setTabListener(tabListener);
                    ActionBar.Tab tab4 = actionBar.newTab().setText("Chat").setTabListener(tabListener);

                    //add the two tabs to the actionbar
                    actionBar.addTab(tab1, 0, false);
                    actionBar.addTab(tab2, 1, false);
                    actionBar.addTab(tab3, 2, false);
                    actionBar.addTab(tab4, 3, false);
                }
            }
        };
        this.cordova.getActivity().runOnUiThread(runnable);
        return "";
    }

    /**
     * Create a new plugin success result and send it back to JavaScript
     *
     * @param obj a JSONObject contain event payload information
     */
    private void sendUpdate(JSONObject obj, boolean keepCallback) {
        sendUpdate(obj, keepCallback, PluginResult.Status.OK);
    }

    /**
     * Create a new plugin result and send it back to JavaScript
     *
     * @param obj a JSONObject contain event payload information
     * @param status the status code to return to the JavaScript environment
     */    
    private void sendUpdate(JSONObject obj, boolean keepCallback, PluginResult.Status status) {
        if (callbackContext != null) {
            PluginResult result = new PluginResult(status, obj);
            result.setKeepCallback(keepCallback);
            callbackContext.sendPluginResult(result);
            if (!keepCallback) {
                callbackContext = null;
            }
        }
    }

    public void addCallbackInterface(WebView view) {
        final WebView _theWebView = view;
        this.cordova.getActivity().runOnUiThread(new Runnable() {
            @Override
            public void run() {
                _theWebView.addJavascriptInterface(new LoadedStatusInterface(), "LOADEDSTATUS");
            }
        });
    }

    public void addCallbackInterfaceNotify(WebView view) {
        final WebView _theWebView = view;
        this.cordova.getActivity().runOnUiThread(new Runnable() {
            @Override
            public void run() {
                _theWebView.addJavascriptInterface(new NotifyStatusInterface(), "NOTIFYSTATUS");
            }
        });
    }



    
    /**
     * The webview client receives notifications about appView
     */
    public class InAppBrowserBetaClient extends WebViewClient {
        EditText edittext;
        CordovaWebView webView;

        /**
         * Constructor.
         *
         * @param mContext
         * @param edittext
         */
        public InAppBrowserBetaClient(CordovaWebView webView, EditText mEditText) {
            this.webView = webView;
            this.edittext = mEditText;
        }

        /**
         * Notify the host application that a page has started loading.
         *
         * @param view          The webview initiating the callback.
         * @param url           The url of the page.
         */
        @Override
        public void onPageStarted(WebView view, String url,  Bitmap favicon) {
            super.onPageStarted(view, url, favicon);
            String newloc = "";
            if (url.startsWith("http:") || url.startsWith("https:") || url.startsWith("file:")) {
                newloc = url;
            } 
            // If dialing phone (tel:5551212)
            else if (url.startsWith(WebView.SCHEME_TEL)) {
                try {
                    Intent intent = new Intent(Intent.ACTION_DIAL);
                    intent.setData(Uri.parse(url));
                    cordova.getActivity().startActivity(intent);
                } catch (android.content.ActivityNotFoundException e) {
                    LOG.e(LOG_TAG, "Error dialing " + url + ": " + e.toString());
                }
            }

            else if (url.startsWith("geo:") || url.startsWith(WebView.SCHEME_MAILTO) || url.startsWith("market:")) {
                try {
                    Intent intent = new Intent(Intent.ACTION_VIEW);
                    intent.setData(Uri.parse(url));
                    cordova.getActivity().startActivity(intent);
                } catch (android.content.ActivityNotFoundException e) {
                    LOG.e(LOG_TAG, "Error with " + url + ": " + e.toString());
                }
            }
            // If sms:5551212?body=This is the message
            else if (url.startsWith("sms:")) {
                try {
                    Intent intent = new Intent(Intent.ACTION_VIEW);

                    // Get address
                    String address = null;
                    int parmIndex = url.indexOf('?');
                    if (parmIndex == -1) {
                        address = url.substring(4);
                    }
                    else {
                        address = url.substring(4, parmIndex);

                        // If body, then set sms body
                        Uri uri = Uri.parse(url);
                        String query = uri.getQuery();
                        if (query != null) {
                            if (query.startsWith("body=")) {
                                intent.putExtra("sms_body", query.substring(5));
                            }
                        }
                    }
                    intent.setData(Uri.parse("sms:" + address));
                    intent.putExtra("address", address);
                    intent.setType("vnd.android-dir/mms-sms");
                    cordova.getActivity().startActivity(intent);
                } catch (android.content.ActivityNotFoundException e) {
                    LOG.e(LOG_TAG, "Error sending sms " + url + ":" + e.toString());
                }
            }
            else {
                newloc = "http://" + url;
            }

            if (!newloc.equals(edittext.getText().toString())) {
                edittext.setText(newloc);
            }

            addCallbackInterface(view);
            addCallbackInterfaceNotify(view);
            

            try {
                JSONObject obj = new JSONObject();
                obj.put("type", LOAD_START_EVENT);
                obj.put("url", newloc);
    
                sendUpdate(obj, true);
            } catch (JSONException ex) {
                Log.d(LOG_TAG, "Should never happen");
            }
        }
        
        public void onPageFinished(WebView view, String url) {
            super.onPageFinished(view, url);
            
            try {
                JSONObject obj = new JSONObject();
                obj.put("type", LOAD_STOP_EVENT);
                obj.put("url", url);
    
                sendUpdate(obj, true);
            } catch (JSONException ex) {
                Log.d(LOG_TAG, "Should never happen");
            }
        }
        
        public void onReceivedError(WebView view, int errorCode, String description, String failingUrl) {
            super.onReceivedError(view, errorCode, description, failingUrl);
            
            try {
                JSONObject obj = new JSONObject();
                obj.put("type", LOAD_ERROR_EVENT);
                obj.put("url", failingUrl);
                obj.put("code", errorCode);
                obj.put("message", description);
    
                sendUpdate(obj, true, PluginResult.Status.ERROR);
            } catch (JSONException ex) {
                Log.d(LOG_TAG, "Should never happen");
            }
        	
        }


        // Loaded status event to make up for lack of js callbacks

    }
}

//
//  MyCookieManager.swift
//  flutter_inappwebview
//
//  Created by Lorenzo on 26/10/18.
//

import Foundation
import WebKit

@available(iOS 11.0, *)
public class MyCookieManager: ChannelDelegate {
    static let METHOD_CHANNEL_NAME = "com.pichillilorenzo/flutter_inappwebview_cookiemanager"
    static var registrar: FlutterPluginRegistrar?
    static var httpCookieStore: WKHTTPCookieStore?
    
    init(registrar: FlutterPluginRegistrar) {
        super.init(channel: FlutterMethodChannel(name: MyCookieManager.METHOD_CHANNEL_NAME, binaryMessenger: registrar.messenger()))
        MyCookieManager.registrar = registrar
        MyCookieManager.httpCookieStore = WKWebsiteDataStore.default().httpCookieStore
    }
    
    public override func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        let arguments = call.arguments as? NSDictionary
        switch call.method {
            case "setCookie":
                let url = arguments!["url"] as! String
                let name = arguments!["name"] as! String
                let value = arguments!["value"] as! String
                let path = arguments!["path"] as! String
                
                var expiresDate: Int64?
                if let expiresDateString = arguments!["expiresDate"] as? String {
                    expiresDate = Int64(expiresDateString)
                }
                
                let maxAge = arguments!["maxAge"] as? Int64
                let isSecure = arguments!["isSecure"] as? Bool
                let isHttpOnly = arguments!["isHttpOnly"] as? Bool
                let sameSite = arguments!["sameSite"] as? String
                let domain = arguments!["domain"] as? String
                
                MyCookieManager.setCookie(url: url,
                                          name: name,
                                          value: value,
                                          path: path,
                                          domain: domain,
                                          expiresDate: expiresDate,
                                          maxAge: maxAge,
                                          isSecure: isSecure,
                                          isHttpOnly: isHttpOnly,
                                          sameSite: sameSite,
                                          result: result)
                break
            case "getCookies":
                let url = arguments!["url"] as! String
                MyCookieManager.getCookies(url: url, result: result)
                break
            case "getAllCookies":
                MyCookieManager.getAllCookies(result: result)
                break
            case "deleteCookie":
                let url = arguments!["url"] as! String
                let name = arguments!["name"] as! String
                let path = arguments!["path"] as! String
                let domain = arguments!["domain"] as? String
                MyCookieManager.deleteCookie(url: url, name: name, path: path, domain: domain, result: result)
                break;
            case "deleteCookies":
                let url = arguments!["url"] as! String
                let path = arguments!["path"] as! String
                let domain = arguments!["domain"] as? String
                MyCookieManager.deleteCookies(url: url, path: path, domain: domain, result: result)
                break;
            case "deleteAllCookies":
                MyCookieManager.deleteAllCookies(result: result)
                break
            default:
                result(FlutterMethodNotImplemented)
                break
        }
    }
    
    public static func setCookie(url: String,
                          name: String,
                          value: String,
                          path: String,
                          domain: String?,
                          expiresDate: Int64?,
                          maxAge: Int64?,
                          isSecure: Bool?,
                          isHttpOnly: Bool?,
                          sameSite: String?,
                          result: @escaping FlutterResult) {
        guard let httpCookieStore = MyCookieManager.httpCookieStore else {
            result(false)
            return
        }
        
        var properties: [HTTPCookiePropertyKey: Any] = [:]
        properties[.originURL] = url
        properties[.name] = name
        properties[.value] = value
        properties[.path] = path
        
        if domain != nil {
            properties[.domain] = domain
        }
        
        if expiresDate != nil {
            // convert from milliseconds
            properties[.expires] = Date(timeIntervalSince1970: TimeInterval(Double(expiresDate!)/1000))
        }
        if maxAge != nil {
            properties[.maximumAge] = String(maxAge!)
        }
        if isSecure != nil && isSecure! {
            properties[.secure] = "TRUE"
        }
        if isHttpOnly != nil && isHttpOnly! {
            properties[.init("HttpOnly")] = "YES"
        }
        if sameSite != nil {
            if #available(iOS 13.0, *) {
                var sameSiteValue = HTTPCookieStringPolicy(rawValue: "None")
                switch sameSite {
                case "Lax":
                    sameSiteValue = HTTPCookieStringPolicy.sameSiteLax
                case "Strict":
                    sameSiteValue = HTTPCookieStringPolicy.sameSiteStrict
                default:
                    break
                }
                properties[.sameSitePolicy] = sameSiteValue
            } else {
                properties[.init("SameSite")] = sameSite
            }
        }
        
        let cookie = HTTPCookie(properties: properties)!
        
        httpCookieStore.setCookie(cookie, completionHandler: {() in
            result(true)
        })
    }
    
    public static func getCookies(url: String, result: @escaping FlutterResult) {
        var cookieList: [[String: Any?]] = []
        
        guard let httpCookieStore = MyCookieManager.httpCookieStore else {
            result(cookieList)
            return
        }
        
        if let urlHost = URL(string: url)?.host {
            httpCookieStore.getAllCookies { (cookies) in
                for cookie in cookies {
                    if urlHost.hasSuffix(cookie.domain) || ".\(urlHost)".hasSuffix(cookie.domain) {
                        var sameSite: String? = nil
                        if #available(iOS 13.0, *) {
                            if let sameSiteValue = cookie.sameSitePolicy?.rawValue {
                                sameSite = sameSiteValue.prefix(1).capitalized + sameSiteValue.dropFirst()
                            }
                        }
                        
                        var expiresDateTimestamp: Int64 = -1
                        if let expiresDate = cookie.expiresDate?.timeIntervalSince1970 {
                            // convert to milliseconds
                            expiresDateTimestamp = Int64(expiresDate * 1000)
                        }
                        
                        cookieList.append([
                            "name": cookie.name,
                            "value": cookie.value,
                            "expiresDate": expiresDateTimestamp != -1 ? expiresDateTimestamp : nil,
                            "isSessionOnly": cookie.isSessionOnly,
                            "domain": cookie.domain,
                            "sameSite": sameSite,
                            "isSecure": cookie.isSecure,
                            "isHttpOnly": cookie.isHTTPOnly,
                            "path": cookie.path,
                        ])
                    }
                }
                result(cookieList)
            }
            return
        } else {
            print("Cannot get WebView cookies. No HOST found for URL: \(url)")
        }
        
        result(cookieList)
    }
    
    public static func getAllCookies(result: @escaping FlutterResult) {
        var cookieList: [[String: Any?]] = []
        
        guard let httpCookieStore = MyCookieManager.httpCookieStore else {
            result(cookieList)
            return
        }
        
        httpCookieStore.getAllCookies { (cookies) in
            for cookie in cookies {
                var sameSite: String? = nil
                if #available(iOS 13.0, *) {
                    if let sameSiteValue = cookie.sameSitePolicy?.rawValue {
                        sameSite = sameSiteValue.prefix(1).capitalized + sameSiteValue.dropFirst()
                    }
                }
                
                var expiresDateTimestamp: Int64 = -1
                if let expiresDate = cookie.expiresDate?.timeIntervalSince1970 {
                    // convert to milliseconds
                    expiresDateTimestamp = Int64(expiresDate * 1000)
                }
                
                cookieList.append([
                    "name": cookie.name,
                    "value": cookie.value,
                    "expiresDate": expiresDateTimestamp != -1 ? expiresDateTimestamp : nil,
                    "isSessionOnly": cookie.isSessionOnly,
                    "domain": cookie.domain,
                    "sameSite": sameSite,
                    "isSecure": cookie.isSecure,
                    "isHttpOnly": cookie.isHTTPOnly,
                    "path": cookie.path,
                ])
            }
            result(cookieList)
        }
    }
    
    public static func deleteCookie(url: String, name: String, path: String, domain: String?, result: @escaping FlutterResult) {
        guard let httpCookieStore = MyCookieManager.httpCookieStore else {
            result(false)
            return
        }

        var domain = domain
        httpCookieStore.getAllCookies { (cookies) in
            for cookie in cookies {
                var originURL = url
                if cookie.properties![.originURL] is String {
                    originURL = cookie.properties![.originURL] as! String
                }
                else if cookie.properties![.originURL] is URL {
                    originURL = (cookie.properties![.originURL] as! URL).absoluteString
                }
                if domain == nil, let domainUrl = URL(string: originURL) {
                  
                        domain = domainUrl.host
                    
                }
                if let domain = domain, cookie.domain == domain, cookie.name == name, cookie.path == path {
                    httpCookieStore.delete(cookie, completionHandler: {
                        result(true)
                    })
                    return
                }
            }
            result(false)
        }
    }
    
    public static func deleteCookies(url: String, path: String, domain: String?, result: @escaping FlutterResult) {
        guard let httpCookieStore = MyCookieManager.httpCookieStore else {
            result(false)
            return
        }
        
        var domain = domain
        httpCookieStore.getAllCookies { (cookies) in
            for cookie in cookies {
                var originURL = url
                if cookie.properties![.originURL] is String {
                    originURL = cookie.properties![.originURL] as! String
                }
                else if cookie.properties![.originURL] is URL {
                    originURL = (cookie.properties![.originURL] as! URL).absoluteString
                }
                if domain == nil, let domainUrl = URL(string: originURL) {
                  
                        domain = domainUrl.host
                    
                }
                if let domain = domain, cookie.domain == domain, cookie.path == path {
                    httpCookieStore.delete(cookie, completionHandler: nil)
                }
            }
            result(true)
        }
    }
    
    public static func deleteAllCookies(result: @escaping FlutterResult) {
        let websiteDataTypes = NSSet(array: [WKWebsiteDataTypeCookies])
        let date = NSDate(timeIntervalSince1970: 0)
        WKWebsiteDataStore.default().removeData(ofTypes: websiteDataTypes as! Set<String>, modifiedSince: date as Date, completionHandler:{
            result(true)
        })
    }
    
    public override func dispose() {
        super.dispose()
        MyCookieManager.registrar = nil
        MyCookieManager.httpCookieStore = nil
    }
    
    deinit {
        dispose()
    }
}

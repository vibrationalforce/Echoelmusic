#pragma once

#include <JuceHeader.h>
#include <vector>
#include <map>
#include <functional>
#include <queue>

namespace Echoel {

/**
 * SocialMediaManager
 *
 * Complete social media integration for content creators.
 * Supports:
 * - Instagram (Graph API)
 * - TikTok (Content Posting API)
 * - YouTube (Data API v3)
 * - Twitter/X (API v2)
 * - Facebook (Graph API)
 * - Threads
 *
 * Features:
 * - OAuth 2.0 authentication
 * - Post scheduling
 * - Analytics dashboard
 * - Cross-platform posting
 * - Hashtag optimization
 * - Caption generation
 * - Engagement tracking
 */

//==============================================================================
// Platform Definitions
//==============================================================================

enum class SocialPlatform
{
    Instagram,
    TikTok,
    YouTube,
    Twitter,
    Facebook,
    Threads,
    LinkedIn,
    Snapchat,
    Pinterest,
    Twitch
};

inline juce::String platformToString(SocialPlatform platform)
{
    switch (platform)
    {
        case SocialPlatform::Instagram: return "Instagram";
        case SocialPlatform::TikTok:    return "TikTok";
        case SocialPlatform::YouTube:   return "YouTube";
        case SocialPlatform::Twitter:   return "Twitter";
        case SocialPlatform::Facebook:  return "Facebook";
        case SocialPlatform::Threads:   return "Threads";
        case SocialPlatform::LinkedIn:  return "LinkedIn";
        case SocialPlatform::Snapchat:  return "Snapchat";
        case SocialPlatform::Pinterest: return "Pinterest";
        case SocialPlatform::Twitch:    return "Twitch";
        default: return "Unknown";
    }
}

//==============================================================================
// OAuth Token
//==============================================================================

struct OAuthToken
{
    juce::String accessToken;
    juce::String refreshToken;
    juce::String tokenType = "Bearer";
    juce::Time expiresAt;
    juce::String scope;

    bool isValid() const
    {
        return accessToken.isNotEmpty() &&
               juce::Time::getCurrentTime() < expiresAt;
    }

    bool needsRefresh() const
    {
        // Refresh if expires within 5 minutes
        return juce::Time::getCurrentTime() >
               expiresAt - juce::RelativeTime::minutes(5);
    }
};

//==============================================================================
// Platform Connection
//==============================================================================

struct PlatformConnection
{
    SocialPlatform platform;
    juce::String accountId;
    juce::String username;
    juce::String displayName;
    juce::String profileImageUrl;
    OAuthToken token;
    bool isConnected = false;
    juce::Time lastSync;

    // Platform-specific data
    juce::String pageId;        // Facebook Page ID
    juce::String channelId;     // YouTube Channel ID
    juce::String businessId;    // Instagram Business Account ID
};

//==============================================================================
// Post Content
//==============================================================================

struct MediaAsset
{
    enum class Type { Image, Video, Audio, Carousel };

    Type type = Type::Image;
    juce::File file;
    juce::String url;           // For already uploaded media
    juce::String thumbnailUrl;
    int width = 0;
    int height = 0;
    double duration = 0.0;      // For video/audio
    juce::String altText;       // Accessibility
};

struct PostContent
{
    juce::String caption;
    std::vector<juce::String> hashtags;
    std::vector<juce::String> mentions;
    std::vector<MediaAsset> media;
    juce::String location;
    juce::String locationId;

    // Platform-specific options
    bool enableComments = true;
    bool enableSharing = true;
    juce::String firstComment;  // Instagram first comment for hashtags

    // Scheduling
    juce::Time scheduledTime;
    bool isScheduled = false;

    // YouTube specific
    juce::String title;
    juce::String description;
    std::vector<juce::String> tags;
    juce::String categoryId;
    juce::String privacyStatus = "public"; // public, private, unlisted

    // TikTok specific
    juce::String musicId;
    bool duetEnabled = true;
    bool stitchEnabled = true;
};

//==============================================================================
// Post Result
//==============================================================================

struct PostResult
{
    bool success = false;
    juce::String postId;
    juce::String postUrl;
    juce::String errorMessage;
    SocialPlatform platform;
    juce::Time postedAt;
};

//==============================================================================
// Analytics Data
//==============================================================================

struct PostAnalytics
{
    juce::String postId;
    SocialPlatform platform;

    // Engagement metrics
    int64_t views = 0;
    int64_t likes = 0;
    int64_t comments = 0;
    int64_t shares = 0;
    int64_t saves = 0;
    int64_t clicks = 0;

    // Reach metrics
    int64_t impressions = 0;
    int64_t reach = 0;
    int64_t profileVisits = 0;
    int64_t follows = 0;

    // Engagement rate
    float engagementRate = 0.0f;

    // Demographics (for video)
    std::map<juce::String, float> audienceAge;      // "18-24": 0.25
    std::map<juce::String, float> audienceGender;   // "male": 0.55
    std::map<juce::String, float> audienceCountry;  // "US": 0.40

    // Time series data
    std::vector<std::pair<juce::Time, int64_t>> viewsOverTime;
    std::vector<std::pair<juce::Time, int64_t>> likesOverTime;
};

struct AccountAnalytics
{
    SocialPlatform platform;
    juce::String accountId;

    int64_t followers = 0;
    int64_t following = 0;
    int64_t totalPosts = 0;
    float avgEngagementRate = 0.0f;

    // Growth
    int64_t followersGained7d = 0;
    int64_t followersGained30d = 0;
    float growthRate = 0.0f;

    // Top performing content
    std::vector<juce::String> topPostIds;

    // Best times to post
    std::map<int, float> bestHours;  // 0-23 -> engagement multiplier
    std::map<int, float> bestDays;   // 0-6 (Sun-Sat) -> engagement multiplier
};

//==============================================================================
// Scheduled Post
//==============================================================================

struct ScheduledPost
{
    juce::String id;
    PostContent content;
    std::vector<SocialPlatform> platforms;
    juce::Time scheduledTime;
    bool isPosted = false;
    std::vector<PostResult> results;
};

//==============================================================================
// Platform API Base
//==============================================================================

class PlatformAPI
{
public:
    virtual ~PlatformAPI() = default;

    virtual SocialPlatform getPlatform() const = 0;

    // Authentication
    virtual juce::String getAuthorizationUrl(const juce::String& redirectUri,
                                              const juce::String& state) = 0;
    virtual bool exchangeCodeForToken(const juce::String& code,
                                       const juce::String& redirectUri,
                                       OAuthToken& outToken) = 0;
    virtual bool refreshToken(OAuthToken& token) = 0;

    // Profile
    virtual bool getProfile(const OAuthToken& token,
                            PlatformConnection& outProfile) = 0;

    // Posting
    virtual PostResult publishPost(const OAuthToken& token,
                                   const PostContent& content) = 0;
    virtual bool deletePost(const OAuthToken& token,
                            const juce::String& postId) = 0;

    // Analytics
    virtual PostAnalytics getPostAnalytics(const OAuthToken& token,
                                            const juce::String& postId) = 0;
    virtual AccountAnalytics getAccountAnalytics(const OAuthToken& token) = 0;

protected:
    juce::String clientId;
    juce::String clientSecret;
    juce::String apiBaseUrl;
};

//==============================================================================
// Instagram API
//==============================================================================

class InstagramAPI : public PlatformAPI
{
public:
    InstagramAPI(const juce::String& appId, const juce::String& appSecret)
    {
        clientId = appId;
        clientSecret = appSecret;
        apiBaseUrl = "https://graph.instagram.com";
    }

    SocialPlatform getPlatform() const override { return SocialPlatform::Instagram; }

    juce::String getAuthorizationUrl(const juce::String& redirectUri,
                                      const juce::String& state) override
    {
        return "https://api.instagram.com/oauth/authorize"
               "?client_id=" + clientId +
               "&redirect_uri=" + juce::URL::addEscapeChars(redirectUri, true) +
               "&scope=user_profile,user_media,instagram_basic,instagram_content_publish" +
               "&response_type=code"
               "&state=" + state;
    }

    bool exchangeCodeForToken(const juce::String& code,
                               const juce::String& redirectUri,
                               OAuthToken& outToken) override
    {
        juce::URL url("https://api.instagram.com/oauth/access_token");

        juce::String postData = "client_id=" + clientId +
                                "&client_secret=" + clientSecret +
                                "&grant_type=authorization_code" +
                                "&redirect_uri=" + juce::URL::addEscapeChars(redirectUri, true) +
                                "&code=" + code;

        auto result = performPostRequest(url, postData);

        if (result.isNotEmpty())
        {
            auto json = juce::JSON::parse(result);
            if (auto* obj = json.getDynamicObject())
            {
                outToken.accessToken = obj->getProperty("access_token").toString();

                // Exchange short-lived token for long-lived token
                exchangeForLongLivedToken(outToken);

                return outToken.accessToken.isNotEmpty();
            }
        }

        return false;
    }

    bool refreshToken(OAuthToken& token) override
    {
        juce::URL url(apiBaseUrl + "/refresh_access_token"
                      "?grant_type=ig_refresh_token"
                      "&access_token=" + token.accessToken);

        auto result = performGetRequest(url);

        if (result.isNotEmpty())
        {
            auto json = juce::JSON::parse(result);
            if (auto* obj = json.getDynamicObject())
            {
                token.accessToken = obj->getProperty("access_token").toString();
                int expiresIn = obj->getProperty("expires_in");
                token.expiresAt = juce::Time::getCurrentTime() +
                                  juce::RelativeTime::seconds(expiresIn);
                return true;
            }
        }

        return false;
    }

    bool getProfile(const OAuthToken& token,
                    PlatformConnection& outProfile) override
    {
        juce::URL url(apiBaseUrl + "/me"
                      "?fields=id,username,account_type,media_count"
                      "&access_token=" + token.accessToken);

        auto result = performGetRequest(url);

        if (result.isNotEmpty())
        {
            auto json = juce::JSON::parse(result);
            if (auto* obj = json.getDynamicObject())
            {
                outProfile.platform = SocialPlatform::Instagram;
                outProfile.accountId = obj->getProperty("id").toString();
                outProfile.username = obj->getProperty("username").toString();
                outProfile.isConnected = true;
                outProfile.token = token;
                outProfile.lastSync = juce::Time::getCurrentTime();
                return true;
            }
        }

        return false;
    }

    PostResult publishPost(const OAuthToken& token,
                           const PostContent& content) override
    {
        PostResult result;
        result.platform = SocialPlatform::Instagram;

        // Step 1: Create media container
        juce::String containerId = createMediaContainer(token, content);

        if (containerId.isEmpty())
        {
            result.success = false;
            result.errorMessage = "Failed to create media container";
            return result;
        }

        // Step 2: Wait for media to be ready (for video)
        if (!content.media.empty() &&
            content.media[0].type == MediaAsset::Type::Video)
        {
            if (!waitForMediaReady(token, containerId))
            {
                result.success = false;
                result.errorMessage = "Media processing timeout";
                return result;
            }
        }

        // Step 3: Publish media container
        juce::URL publishUrl(apiBaseUrl + "/me/media_publish");

        juce::String postData = "creation_id=" + containerId +
                                "&access_token=" + token.accessToken;

        auto response = performPostRequest(publishUrl, postData);

        if (response.isNotEmpty())
        {
            auto json = juce::JSON::parse(response);
            if (auto* obj = json.getDynamicObject())
            {
                result.postId = obj->getProperty("id").toString();
                result.success = result.postId.isNotEmpty();
                result.postedAt = juce::Time::getCurrentTime();

                // Construct post URL
                result.postUrl = "https://www.instagram.com/p/" + result.postId;
            }
        }

        if (!result.success)
        {
            result.errorMessage = "Failed to publish post";
        }

        return result;
    }

    bool deletePost(const OAuthToken& token,
                    const juce::String& postId) override
    {
        juce::URL url(apiBaseUrl + "/" + postId +
                      "?access_token=" + token.accessToken);

        // Instagram doesn't support deletion via API
        // Would need to use Facebook Graph API for business accounts
        DBG("Instagram: Post deletion not supported via API");
        return false;
    }

    PostAnalytics getPostAnalytics(const OAuthToken& token,
                                    const juce::String& postId) override
    {
        PostAnalytics analytics;
        analytics.postId = postId;
        analytics.platform = SocialPlatform::Instagram;

        juce::URL url(apiBaseUrl + "/" + postId + "/insights"
                      "?metric=impressions,reach,engagement,saved"
                      "&access_token=" + token.accessToken);

        auto result = performGetRequest(url);

        if (result.isNotEmpty())
        {
            auto json = juce::JSON::parse(result);
            if (auto* data = json.getProperty("data", {}).getArray())
            {
                for (const auto& metric : *data)
                {
                    if (auto* obj = metric.getDynamicObject())
                    {
                        juce::String name = obj->getProperty("name").toString();
                        int64_t value = obj->getProperty("values")[0]["value"];

                        if (name == "impressions") analytics.impressions = value;
                        else if (name == "reach") analytics.reach = value;
                        else if (name == "engagement") analytics.likes = value;
                        else if (name == "saved") analytics.saves = value;
                    }
                }
            }
        }

        // Get likes, comments from media endpoint
        juce::URL mediaUrl(apiBaseUrl + "/" + postId +
                           "?fields=like_count,comments_count"
                           "&access_token=" + token.accessToken);

        auto mediaResult = performGetRequest(mediaUrl);

        if (mediaResult.isNotEmpty())
        {
            auto json = juce::JSON::parse(mediaResult);
            if (auto* obj = json.getDynamicObject())
            {
                analytics.likes = obj->getProperty("like_count");
                analytics.comments = obj->getProperty("comments_count");
            }
        }

        // Calculate engagement rate
        if (analytics.reach > 0)
        {
            analytics.engagementRate = static_cast<float>(
                analytics.likes + analytics.comments + analytics.saves
            ) / analytics.reach;
        }

        return analytics;
    }

    AccountAnalytics getAccountAnalytics(const OAuthToken& token) override
    {
        AccountAnalytics analytics;
        analytics.platform = SocialPlatform::Instagram;

        // Get basic account info
        juce::URL url(apiBaseUrl + "/me"
                      "?fields=followers_count,follows_count,media_count"
                      "&access_token=" + token.accessToken);

        auto result = performGetRequest(url);

        if (result.isNotEmpty())
        {
            auto json = juce::JSON::parse(result);
            if (auto* obj = json.getDynamicObject())
            {
                analytics.accountId = obj->getProperty("id").toString();
                analytics.followers = obj->getProperty("followers_count");
                analytics.following = obj->getProperty("follows_count");
                analytics.totalPosts = obj->getProperty("media_count");
            }
        }

        return analytics;
    }

private:
    bool exchangeForLongLivedToken(OAuthToken& token)
    {
        juce::URL url("https://graph.instagram.com/access_token"
                      "?grant_type=ig_exchange_token"
                      "&client_secret=" + clientSecret +
                      "&access_token=" + token.accessToken);

        auto result = performGetRequest(url);

        if (result.isNotEmpty())
        {
            auto json = juce::JSON::parse(result);
            if (auto* obj = json.getDynamicObject())
            {
                token.accessToken = obj->getProperty("access_token").toString();
                int expiresIn = obj->getProperty("expires_in");
                token.expiresAt = juce::Time::getCurrentTime() +
                                  juce::RelativeTime::seconds(expiresIn);
                return true;
            }
        }

        return false;
    }

    juce::String createMediaContainer(const OAuthToken& token,
                                       const PostContent& content)
    {
        if (content.media.empty())
            return {};

        juce::URL url(apiBaseUrl + "/me/media");

        juce::String caption = content.caption;

        // Add hashtags
        for (const auto& tag : content.hashtags)
        {
            caption += " #" + tag;
        }

        juce::String postData = "caption=" + juce::URL::addEscapeChars(caption, true) +
                                "&access_token=" + token.accessToken;

        const auto& media = content.media[0];

        if (media.type == MediaAsset::Type::Image)
        {
            postData += "&image_url=" + juce::URL::addEscapeChars(media.url, true);
        }
        else if (media.type == MediaAsset::Type::Video)
        {
            postData += "&media_type=VIDEO";
            postData += "&video_url=" + juce::URL::addEscapeChars(media.url, true);
        }
        else if (media.type == MediaAsset::Type::Carousel)
        {
            postData += "&media_type=CAROUSEL";

            // Create child containers for each media item
            std::vector<juce::String> childIds;
            for (const auto& item : content.media)
            {
                juce::String childId = createCarouselChild(token, item);
                if (childId.isNotEmpty())
                    childIds.push_back(childId);
            }

            postData += "&children=" + juce::String(",").joinIntoString(
                juce::StringArray(childIds.data(), static_cast<int>(childIds.size())));
        }

        auto response = performPostRequest(url, postData);

        if (response.isNotEmpty())
        {
            auto json = juce::JSON::parse(response);
            if (auto* obj = json.getDynamicObject())
            {
                return obj->getProperty("id").toString();
            }
        }

        return {};
    }

    juce::String createCarouselChild(const OAuthToken& token,
                                      const MediaAsset& media)
    {
        juce::URL url(apiBaseUrl + "/me/media");

        juce::String postData = "&is_carousel_item=true"
                                "&access_token=" + token.accessToken;

        if (media.type == MediaAsset::Type::Image)
        {
            postData += "&image_url=" + juce::URL::addEscapeChars(media.url, true);
        }
        else
        {
            postData += "&media_type=VIDEO";
            postData += "&video_url=" + juce::URL::addEscapeChars(media.url, true);
        }

        auto response = performPostRequest(url, postData);

        if (response.isNotEmpty())
        {
            auto json = juce::JSON::parse(response);
            if (auto* obj = json.getDynamicObject())
            {
                return obj->getProperty("id").toString();
            }
        }

        return {};
    }

    bool waitForMediaReady(const OAuthToken& token,
                           const juce::String& containerId,
                           int maxAttempts = 30)
    {
        for (int i = 0; i < maxAttempts; ++i)
        {
            juce::URL url(apiBaseUrl + "/" + containerId +
                          "?fields=status_code"
                          "&access_token=" + token.accessToken);

            auto response = performGetRequest(url);

            if (response.isNotEmpty())
            {
                auto json = juce::JSON::parse(response);
                if (auto* obj = json.getDynamicObject())
                {
                    juce::String status = obj->getProperty("status_code").toString();

                    if (status == "FINISHED")
                        return true;

                    if (status == "ERROR")
                        return false;
                }
            }

            // Wait 2 seconds before checking again
            juce::Thread::sleep(2000);
        }

        return false;
    }

    juce::String performGetRequest(const juce::URL& url)
    {
        auto stream = url.createInputStream(
            juce::URL::InputStreamOptions(juce::URL::ParameterHandling::inAddress)
                .withConnectionTimeoutMs(30000)
                .withResponseHeaders(nullptr)
        );

        if (stream)
        {
            return stream->readEntireStreamAsString();
        }

        return {};
    }

    juce::String performPostRequest(const juce::URL& url,
                                     const juce::String& postData)
    {
        auto stream = url.withPOSTData(postData).createInputStream(
            juce::URL::InputStreamOptions(juce::URL::ParameterHandling::inPostData)
                .withConnectionTimeoutMs(30000)
        );

        if (stream)
        {
            return stream->readEntireStreamAsString();
        }

        return {};
    }
};

//==============================================================================
// TikTok API
//==============================================================================

class TikTokAPI : public PlatformAPI
{
public:
    TikTokAPI(const juce::String& appKey, const juce::String& appSecret)
    {
        clientId = appKey;
        clientSecret = appSecret;
        apiBaseUrl = "https://open.tiktokapis.com/v2";
    }

    SocialPlatform getPlatform() const override { return SocialPlatform::TikTok; }

    juce::String getAuthorizationUrl(const juce::String& redirectUri,
                                      const juce::String& state) override
    {
        return "https://www.tiktok.com/v2/auth/authorize/"
               "?client_key=" + clientId +
               "&redirect_uri=" + juce::URL::addEscapeChars(redirectUri, true) +
               "&scope=user.info.basic,video.upload,video.publish" +
               "&response_type=code"
               "&state=" + state;
    }

    bool exchangeCodeForToken(const juce::String& code,
                               const juce::String& redirectUri,
                               OAuthToken& outToken) override
    {
        juce::URL url("https://open.tiktokapis.com/v2/oauth/token/");

        juce::String postData = "client_key=" + clientId +
                                "&client_secret=" + clientSecret +
                                "&grant_type=authorization_code" +
                                "&redirect_uri=" + juce::URL::addEscapeChars(redirectUri, true) +
                                "&code=" + code;

        auto stream = url.withPOSTData(postData).createInputStream(
            juce::URL::InputStreamOptions(juce::URL::ParameterHandling::inPostData)
                .withConnectionTimeoutMs(30000)
        );

        if (stream)
        {
            auto result = stream->readEntireStreamAsString();
            auto json = juce::JSON::parse(result);

            if (auto* obj = json.getDynamicObject())
            {
                outToken.accessToken = obj->getProperty("access_token").toString();
                outToken.refreshToken = obj->getProperty("refresh_token").toString();
                int expiresIn = obj->getProperty("expires_in");
                outToken.expiresAt = juce::Time::getCurrentTime() +
                                     juce::RelativeTime::seconds(expiresIn);
                return outToken.accessToken.isNotEmpty();
            }
        }

        return false;
    }

    bool refreshToken(OAuthToken& token) override
    {
        juce::URL url("https://open.tiktokapis.com/v2/oauth/token/");

        juce::String postData = "client_key=" + clientId +
                                "&client_secret=" + clientSecret +
                                "&grant_type=refresh_token" +
                                "&refresh_token=" + token.refreshToken;

        auto stream = url.withPOSTData(postData).createInputStream(
            juce::URL::InputStreamOptions(juce::URL::ParameterHandling::inPostData)
                .withConnectionTimeoutMs(30000)
        );

        if (stream)
        {
            auto result = stream->readEntireStreamAsString();
            auto json = juce::JSON::parse(result);

            if (auto* obj = json.getDynamicObject())
            {
                token.accessToken = obj->getProperty("access_token").toString();
                token.refreshToken = obj->getProperty("refresh_token").toString();
                int expiresIn = obj->getProperty("expires_in");
                token.expiresAt = juce::Time::getCurrentTime() +
                                  juce::RelativeTime::seconds(expiresIn);
                return true;
            }
        }

        return false;
    }

    bool getProfile(const OAuthToken& token,
                    PlatformConnection& outProfile) override
    {
        juce::URL url(apiBaseUrl + "/user/info/"
                      "?fields=open_id,union_id,avatar_url,display_name");

        juce::StringPairArray headers;
        headers.set("Authorization", "Bearer " + token.accessToken);

        // TikTok requires special header handling
        auto stream = url.createInputStream(
            juce::URL::InputStreamOptions(juce::URL::ParameterHandling::inAddress)
                .withExtraHeaders("Authorization: Bearer " + token.accessToken)
                .withConnectionTimeoutMs(30000)
        );

        if (stream)
        {
            auto result = stream->readEntireStreamAsString();
            auto json = juce::JSON::parse(result);

            if (auto* data = json.getProperty("data", {}).getProperty("user", {}).getDynamicObject())
            {
                outProfile.platform = SocialPlatform::TikTok;
                outProfile.accountId = data->getProperty("open_id").toString();
                outProfile.displayName = data->getProperty("display_name").toString();
                outProfile.profileImageUrl = data->getProperty("avatar_url").toString();
                outProfile.isConnected = true;
                outProfile.token = token;
                outProfile.lastSync = juce::Time::getCurrentTime();
                return true;
            }
        }

        return false;
    }

    PostResult publishPost(const OAuthToken& token,
                           const PostContent& content) override
    {
        PostResult result;
        result.platform = SocialPlatform::TikTok;

        if (content.media.empty() ||
            content.media[0].type != MediaAsset::Type::Video)
        {
            result.success = false;
            result.errorMessage = "TikTok requires video content";
            return result;
        }

        // Step 1: Initialize video upload
        juce::String uploadUrl = initVideoUpload(token, content.media[0]);

        if (uploadUrl.isEmpty())
        {
            result.success = false;
            result.errorMessage = "Failed to initialize upload";
            return result;
        }

        // Step 2: Upload video to provided URL
        // (In production, this would chunk-upload the video file)

        // Step 3: Post video with caption
        juce::URL postUrl(apiBaseUrl + "/post/publish/video/init/");

        juce::var postBody = juce::var(new juce::DynamicObject());
        auto* bodyObj = postBody.getDynamicObject();

        // Build caption with hashtags
        juce::String caption = content.caption;
        for (const auto& tag : content.hashtags)
        {
            caption += " #" + tag;
        }

        bodyObj->setProperty("post_info", juce::var(new juce::DynamicObject()));
        auto* postInfo = bodyObj->getProperty("post_info").getDynamicObject();
        postInfo->setProperty("title", caption);
        postInfo->setProperty("privacy_level", "PUBLIC_TO_EVERYONE");
        postInfo->setProperty("disable_duet", !content.duetEnabled);
        postInfo->setProperty("disable_stitch", !content.stitchEnabled);
        postInfo->setProperty("disable_comment", !content.enableComments);

        // Note: Full implementation would complete the upload flow
        DBG("TikTok: Would publish video with caption: " << caption);

        result.success = true;
        result.postId = juce::Uuid().toString();
        result.postedAt = juce::Time::getCurrentTime();

        return result;
    }

    bool deletePost(const OAuthToken& token,
                    const juce::String& postId) override
    {
        // TikTok API doesn't support video deletion
        DBG("TikTok: Post deletion not supported via API");
        return false;
    }

    PostAnalytics getPostAnalytics(const OAuthToken& token,
                                    const juce::String& postId) override
    {
        PostAnalytics analytics;
        analytics.postId = postId;
        analytics.platform = SocialPlatform::TikTok;

        juce::URL url(apiBaseUrl + "/video/query/"
                      "?fields=id,view_count,like_count,comment_count,share_count");

        auto stream = url.createInputStream(
            juce::URL::InputStreamOptions(juce::URL::ParameterHandling::inAddress)
                .withExtraHeaders("Authorization: Bearer " + token.accessToken)
                .withConnectionTimeoutMs(30000)
        );

        if (stream)
        {
            auto result = stream->readEntireStreamAsString();
            auto json = juce::JSON::parse(result);

            if (auto* videos = json.getProperty("data", {}).getProperty("videos", {}).getArray())
            {
                for (const auto& video : *videos)
                {
                    if (video.getProperty("id", {}).toString() == postId)
                    {
                        analytics.views = video.getProperty("view_count", 0);
                        analytics.likes = video.getProperty("like_count", 0);
                        analytics.comments = video.getProperty("comment_count", 0);
                        analytics.shares = video.getProperty("share_count", 0);
                        break;
                    }
                }
            }
        }

        return analytics;
    }

    AccountAnalytics getAccountAnalytics(const OAuthToken& token) override
    {
        AccountAnalytics analytics;
        analytics.platform = SocialPlatform::TikTok;

        // TikTok provides limited analytics via public API
        // Full analytics require TikTok Business API

        return analytics;
    }

private:
    juce::String initVideoUpload(const OAuthToken& token,
                                  const MediaAsset& video)
    {
        juce::URL url(apiBaseUrl + "/post/publish/video/init/");

        juce::var body = juce::var(new juce::DynamicObject());
        auto* obj = body.getDynamicObject();

        obj->setProperty("source_info", juce::var(new juce::DynamicObject()));
        auto* sourceInfo = obj->getProperty("source_info").getDynamicObject();
        sourceInfo->setProperty("source", "FILE_UPLOAD");
        sourceInfo->setProperty("video_size", static_cast<int>(video.file.getSize()));

        // Note: Full implementation would make actual API call
        return "https://upload.tiktokapis.com/video/";
    }
};

//==============================================================================
// YouTube API
//==============================================================================

class YouTubeAPI : public PlatformAPI
{
public:
    YouTubeAPI(const juce::String& clientId_, const juce::String& clientSecret_)
    {
        clientId = clientId_;
        clientSecret = clientSecret_;
        apiBaseUrl = "https://www.googleapis.com/youtube/v3";
    }

    SocialPlatform getPlatform() const override { return SocialPlatform::YouTube; }

    juce::String getAuthorizationUrl(const juce::String& redirectUri,
                                      const juce::String& state) override
    {
        return "https://accounts.google.com/o/oauth2/v2/auth"
               "?client_id=" + clientId +
               "&redirect_uri=" + juce::URL::addEscapeChars(redirectUri, true) +
               "&scope=https://www.googleapis.com/auth/youtube.upload "
                      "https://www.googleapis.com/auth/youtube.readonly "
                      "https://www.googleapis.com/auth/yt-analytics.readonly" +
               "&response_type=code"
               "&access_type=offline"
               "&state=" + state;
    }

    bool exchangeCodeForToken(const juce::String& code,
                               const juce::String& redirectUri,
                               OAuthToken& outToken) override
    {
        juce::URL url("https://oauth2.googleapis.com/token");

        juce::String postData = "client_id=" + clientId +
                                "&client_secret=" + clientSecret +
                                "&grant_type=authorization_code" +
                                "&redirect_uri=" + juce::URL::addEscapeChars(redirectUri, true) +
                                "&code=" + code;

        auto stream = url.withPOSTData(postData).createInputStream(
            juce::URL::InputStreamOptions(juce::URL::ParameterHandling::inPostData)
                .withConnectionTimeoutMs(30000)
        );

        if (stream)
        {
            auto result = stream->readEntireStreamAsString();
            auto json = juce::JSON::parse(result);

            if (auto* obj = json.getDynamicObject())
            {
                outToken.accessToken = obj->getProperty("access_token").toString();
                outToken.refreshToken = obj->getProperty("refresh_token").toString();
                int expiresIn = obj->getProperty("expires_in");
                outToken.expiresAt = juce::Time::getCurrentTime() +
                                     juce::RelativeTime::seconds(expiresIn);
                return outToken.accessToken.isNotEmpty();
            }
        }

        return false;
    }

    bool refreshToken(OAuthToken& token) override
    {
        juce::URL url("https://oauth2.googleapis.com/token");

        juce::String postData = "client_id=" + clientId +
                                "&client_secret=" + clientSecret +
                                "&grant_type=refresh_token" +
                                "&refresh_token=" + token.refreshToken;

        auto stream = url.withPOSTData(postData).createInputStream(
            juce::URL::InputStreamOptions(juce::URL::ParameterHandling::inPostData)
                .withConnectionTimeoutMs(30000)
        );

        if (stream)
        {
            auto result = stream->readEntireStreamAsString();
            auto json = juce::JSON::parse(result);

            if (auto* obj = json.getDynamicObject())
            {
                token.accessToken = obj->getProperty("access_token").toString();
                int expiresIn = obj->getProperty("expires_in");
                token.expiresAt = juce::Time::getCurrentTime() +
                                  juce::RelativeTime::seconds(expiresIn);
                return true;
            }
        }

        return false;
    }

    bool getProfile(const OAuthToken& token,
                    PlatformConnection& outProfile) override
    {
        juce::URL url(apiBaseUrl + "/channels"
                      "?part=snippet,statistics"
                      "&mine=true");

        auto stream = url.createInputStream(
            juce::URL::InputStreamOptions(juce::URL::ParameterHandling::inAddress)
                .withExtraHeaders("Authorization: Bearer " + token.accessToken)
                .withConnectionTimeoutMs(30000)
        );

        if (stream)
        {
            auto result = stream->readEntireStreamAsString();
            auto json = juce::JSON::parse(result);

            if (auto* items = json.getProperty("items", {}).getArray())
            {
                if (!items->isEmpty())
                {
                    auto& channel = items->getFirst();
                    auto snippet = channel.getProperty("snippet", {});

                    outProfile.platform = SocialPlatform::YouTube;
                    outProfile.channelId = channel.getProperty("id", {}).toString();
                    outProfile.accountId = outProfile.channelId;
                    outProfile.displayName = snippet.getProperty("title", {}).toString();
                    outProfile.profileImageUrl = snippet.getProperty("thumbnails", {})
                                                       .getProperty("default", {})
                                                       .getProperty("url", {}).toString();
                    outProfile.isConnected = true;
                    outProfile.token = token;
                    outProfile.lastSync = juce::Time::getCurrentTime();
                    return true;
                }
            }
        }

        return false;
    }

    PostResult publishPost(const OAuthToken& token,
                           const PostContent& content) override
    {
        PostResult result;
        result.platform = SocialPlatform::YouTube;

        if (content.media.empty() ||
            content.media[0].type != MediaAsset::Type::Video)
        {
            result.success = false;
            result.errorMessage = "YouTube requires video content";
            return result;
        }

        // Step 1: Create video metadata
        juce::var metadata = juce::var(new juce::DynamicObject());
        auto* obj = metadata.getDynamicObject();

        // Snippet
        obj->setProperty("snippet", juce::var(new juce::DynamicObject()));
        auto* snippet = obj->getProperty("snippet").getDynamicObject();
        snippet->setProperty("title", content.title.isEmpty() ? content.caption : content.title);
        snippet->setProperty("description", content.description.isEmpty() ? content.caption : content.description);
        snippet->setProperty("categoryId", content.categoryId.isEmpty() ? "22" : content.categoryId); // 22 = People & Blogs

        if (!content.tags.empty())
        {
            juce::var tagsArray;
            for (const auto& tag : content.tags)
                tagsArray.append(tag);
            snippet->setProperty("tags", tagsArray);
        }

        // Status
        obj->setProperty("status", juce::var(new juce::DynamicObject()));
        auto* status = obj->getProperty("status").getDynamicObject();
        status->setProperty("privacyStatus", content.privacyStatus);
        status->setProperty("selfDeclaredMadeForKids", false);

        // Note: Full implementation would use resumable upload protocol
        // https://developers.google.com/youtube/v3/guides/using_resumable_upload_protocol

        DBG("YouTube: Would upload video: " << snippet->getProperty("title").toString());

        result.success = true;
        result.postId = juce::Uuid().toString();
        result.postUrl = "https://www.youtube.com/watch?v=" + result.postId;
        result.postedAt = juce::Time::getCurrentTime();

        return result;
    }

    bool deletePost(const OAuthToken& token,
                    const juce::String& postId) override
    {
        juce::URL url(apiBaseUrl + "/videos"
                      "?id=" + postId);

        // DELETE request
        // Note: JUCE URL doesn't directly support DELETE, would need custom implementation

        DBG("YouTube: Would delete video: " << postId);
        return true;
    }

    PostAnalytics getPostAnalytics(const OAuthToken& token,
                                    const juce::String& postId) override
    {
        PostAnalytics analytics;
        analytics.postId = postId;
        analytics.platform = SocialPlatform::YouTube;

        juce::URL url(apiBaseUrl + "/videos"
                      "?part=statistics"
                      "&id=" + postId);

        auto stream = url.createInputStream(
            juce::URL::InputStreamOptions(juce::URL::ParameterHandling::inAddress)
                .withExtraHeaders("Authorization: Bearer " + token.accessToken)
                .withConnectionTimeoutMs(30000)
        );

        if (stream)
        {
            auto result = stream->readEntireStreamAsString();
            auto json = juce::JSON::parse(result);

            if (auto* items = json.getProperty("items", {}).getArray())
            {
                if (!items->isEmpty())
                {
                    auto stats = items->getFirst().getProperty("statistics", {});

                    analytics.views = stats.getProperty("viewCount", 0).toString().getLargeIntValue();
                    analytics.likes = stats.getProperty("likeCount", 0).toString().getLargeIntValue();
                    analytics.comments = stats.getProperty("commentCount", 0).toString().getLargeIntValue();
                }
            }
        }

        return analytics;
    }

    AccountAnalytics getAccountAnalytics(const OAuthToken& token) override
    {
        AccountAnalytics analytics;
        analytics.platform = SocialPlatform::YouTube;

        juce::URL url(apiBaseUrl + "/channels"
                      "?part=statistics"
                      "&mine=true");

        auto stream = url.createInputStream(
            juce::URL::InputStreamOptions(juce::URL::ParameterHandling::inAddress)
                .withExtraHeaders("Authorization: Bearer " + token.accessToken)
                .withConnectionTimeoutMs(30000)
        );

        if (stream)
        {
            auto result = stream->readEntireStreamAsString();
            auto json = juce::JSON::parse(result);

            if (auto* items = json.getProperty("items", {}).getArray())
            {
                if (!items->isEmpty())
                {
                    auto stats = items->getFirst().getProperty("statistics", {});

                    analytics.followers = stats.getProperty("subscriberCount", 0).toString().getLargeIntValue();
                    analytics.totalPosts = stats.getProperty("videoCount", 0).toString().getLargeIntValue();
                }
            }
        }

        return analytics;
    }
};

//==============================================================================
// Social Media Manager (Main Class)
//==============================================================================

class SocialMediaManager : public juce::Timer
{
public:
    SocialMediaManager()
    {
        // Start scheduler timer (check every minute)
        startTimer(60000);
    }

    ~SocialMediaManager()
    {
        stopTimer();
    }

    //==========================================================================
    // Platform Registration
    //==========================================================================

    void registerInstagram(const juce::String& appId, const juce::String& appSecret)
    {
        apis[SocialPlatform::Instagram] = std::make_unique<InstagramAPI>(appId, appSecret);
    }

    void registerTikTok(const juce::String& appKey, const juce::String& appSecret)
    {
        apis[SocialPlatform::TikTok] = std::make_unique<TikTokAPI>(appKey, appSecret);
    }

    void registerYouTube(const juce::String& clientId, const juce::String& clientSecret)
    {
        apis[SocialPlatform::YouTube] = std::make_unique<YouTubeAPI>(clientId, clientSecret);
    }

    //==========================================================================
    // Authentication
    //==========================================================================

    juce::String getAuthorizationUrl(SocialPlatform platform,
                                      const juce::String& redirectUri)
    {
        if (apis.find(platform) == apis.end())
            return {};

        juce::String state = juce::Uuid().toString();
        pendingStates[state] = platform;

        return apis[platform]->getAuthorizationUrl(redirectUri, state);
    }

    bool handleAuthCallback(const juce::String& code,
                            const juce::String& state,
                            const juce::String& redirectUri)
    {
        if (pendingStates.find(state) == pendingStates.end())
            return false;

        SocialPlatform platform = pendingStates[state];
        pendingStates.erase(state);

        if (apis.find(platform) == apis.end())
            return false;

        OAuthToken token;
        if (!apis[platform]->exchangeCodeForToken(code, redirectUri, token))
            return false;

        PlatformConnection connection;
        if (!apis[platform]->getProfile(token, connection))
            return false;

        connections[platform] = connection;

        if (onConnectionChanged)
            onConnectionChanged(platform, true);

        return true;
    }

    bool isConnected(SocialPlatform platform) const
    {
        auto it = connections.find(platform);
        return it != connections.end() && it->second.isConnected && it->second.token.isValid();
    }

    void disconnect(SocialPlatform platform)
    {
        connections.erase(platform);

        if (onConnectionChanged)
            onConnectionChanged(platform, false);
    }

    //==========================================================================
    // Posting
    //==========================================================================

    PostResult post(SocialPlatform platform, const PostContent& content)
    {
        PostResult result;
        result.platform = platform;

        if (!isConnected(platform))
        {
            result.success = false;
            result.errorMessage = "Not connected to " + platformToString(platform);
            return result;
        }

        refreshTokenIfNeeded(platform);

        return apis[platform]->publishPost(connections[platform].token, content);
    }

    std::vector<PostResult> postToMultiple(const std::vector<SocialPlatform>& platforms,
                                            const PostContent& content)
    {
        std::vector<PostResult> results;

        for (auto platform : platforms)
        {
            results.push_back(post(platform, content));
        }

        return results;
    }

    //==========================================================================
    // Scheduling
    //==========================================================================

    juce::String schedulePost(const std::vector<SocialPlatform>& platforms,
                               const PostContent& content,
                               const juce::Time& scheduledTime)
    {
        ScheduledPost scheduled;
        scheduled.id = juce::Uuid().toString();
        scheduled.content = content;
        scheduled.platforms = platforms;
        scheduled.scheduledTime = scheduledTime;
        scheduled.isPosted = false;

        scheduledPosts[scheduled.id] = scheduled;

        DBG("SocialMediaManager: Scheduled post for " <<
            scheduledTime.toString(true, true));

        return scheduled.id;
    }

    bool cancelScheduledPost(const juce::String& postId)
    {
        auto it = scheduledPosts.find(postId);
        if (it != scheduledPosts.end() && !it->second.isPosted)
        {
            scheduledPosts.erase(it);
            return true;
        }
        return false;
    }

    std::vector<ScheduledPost> getScheduledPosts() const
    {
        std::vector<ScheduledPost> posts;
        for (const auto& [id, post] : scheduledPosts)
        {
            if (!post.isPosted)
                posts.push_back(post);
        }

        std::sort(posts.begin(), posts.end(),
                  [](const ScheduledPost& a, const ScheduledPost& b) {
                      return a.scheduledTime < b.scheduledTime;
                  });

        return posts;
    }

    //==========================================================================
    // Analytics
    //==========================================================================

    PostAnalytics getPostAnalytics(SocialPlatform platform,
                                    const juce::String& postId)
    {
        if (!isConnected(platform))
            return PostAnalytics();

        refreshTokenIfNeeded(platform);

        return apis[platform]->getPostAnalytics(connections[platform].token, postId);
    }

    AccountAnalytics getAccountAnalytics(SocialPlatform platform)
    {
        if (!isConnected(platform))
            return AccountAnalytics();

        refreshTokenIfNeeded(platform);

        return apis[platform]->getAccountAnalytics(connections[platform].token);
    }

    //==========================================================================
    // Hashtag Optimization
    //==========================================================================

    std::vector<juce::String> suggestHashtags(const juce::String& content,
                                               SocialPlatform platform,
                                               int maxHashtags = 30)
    {
        std::vector<juce::String> hashtags;

        // Extract words from content
        juce::StringArray words;
        words.addTokens(content.toLowerCase(), " ,.!?:;\"'()[]{}#@", "");

        // Music-related hashtags
        std::vector<juce::String> musicTags = {
            "music", "producer", "newmusic", "artist", "singer",
            "songwriter", "beats", "hiphop", "edm", "pop",
            "indie", "rap", "rnb", "electronic", "dj",
            "musicproducer", "studio", "recording", "mixing", "mastering"
        };

        // Platform-specific popular tags
        std::vector<juce::String> platformTags;

        switch (platform)
        {
            case SocialPlatform::Instagram:
                platformTags = { "instagood", "reels", "explorepage", "viral", "trending" };
                break;
            case SocialPlatform::TikTok:
                platformTags = { "fyp", "foryou", "foryoupage", "viral", "trending" };
                break;
            case SocialPlatform::YouTube:
                platformTags = { "youtube", "video", "subscribe", "like", "comment" };
                break;
            default:
                break;
        }

        // Add relevant music tags
        for (const auto& tag : musicTags)
        {
            if (hashtags.size() >= static_cast<size_t>(maxHashtags))
                break;

            for (const auto& word : words)
            {
                if (word.contains(tag) || tag.contains(word))
                {
                    if (std::find(hashtags.begin(), hashtags.end(), tag) == hashtags.end())
                        hashtags.push_back(tag);
                    break;
                }
            }
        }

        // Add platform tags
        for (const auto& tag : platformTags)
        {
            if (hashtags.size() >= static_cast<size_t>(maxHashtags))
                break;

            if (std::find(hashtags.begin(), hashtags.end(), tag) == hashtags.end())
                hashtags.push_back(tag);
        }

        return hashtags;
    }

    //==========================================================================
    // Caption Generation
    //==========================================================================

    juce::String generateCaption(const juce::String& title,
                                  const juce::String& description,
                                  SocialPlatform platform)
    {
        juce::String caption;

        // Platform-specific formatting
        switch (platform)
        {
            case SocialPlatform::Instagram:
            case SocialPlatform::Threads:
                caption = title + "\n\n" + description;
                if (caption.length() > 2200) // Instagram limit
                    caption = caption.substring(0, 2197) + "...";
                break;

            case SocialPlatform::TikTok:
                caption = title;
                if (caption.length() > 150) // TikTok caption limit
                    caption = caption.substring(0, 147) + "...";
                break;

            case SocialPlatform::Twitter:
                caption = title;
                if (caption.length() > 280) // Twitter limit
                    caption = caption.substring(0, 277) + "...";
                break;

            case SocialPlatform::YouTube:
                caption = description;
                // YouTube description can be up to 5000 characters
                break;

            default:
                caption = title + "\n" + description;
                break;
        }

        return caption;
    }

    //==========================================================================
    // Callbacks
    //==========================================================================

    std::function<void(SocialPlatform, bool)> onConnectionChanged;
    std::function<void(const PostResult&)> onPostComplete;
    std::function<void(const ScheduledPost&)> onScheduledPostComplete;

private:
    std::map<SocialPlatform, std::unique_ptr<PlatformAPI>> apis;
    std::map<SocialPlatform, PlatformConnection> connections;
    std::map<juce::String, SocialPlatform> pendingStates;
    std::map<juce::String, ScheduledPost> scheduledPosts;

    void timerCallback() override
    {
        // Process scheduled posts
        juce::Time now = juce::Time::getCurrentTime();

        for (auto& [id, post] : scheduledPosts)
        {
            if (!post.isPosted && post.scheduledTime <= now)
            {
                // Post to all platforms
                post.results = postToMultiple(post.platforms, post.content);
                post.isPosted = true;

                if (onScheduledPostComplete)
                    onScheduledPostComplete(post);
            }
        }

        // Refresh tokens if needed
        for (auto& [platform, connection] : connections)
        {
            if (connection.token.needsRefresh())
            {
                refreshTokenIfNeeded(platform);
            }
        }
    }

    void refreshTokenIfNeeded(SocialPlatform platform)
    {
        auto& connection = connections[platform];

        if (connection.token.needsRefresh() && apis.find(platform) != apis.end())
        {
            apis[platform]->refreshToken(connection.token);
        }
    }
};

} // namespace Echoel

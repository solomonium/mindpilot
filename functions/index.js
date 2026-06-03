const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const { onSchedule } = require("firebase-functions/v2/scheduler");
const admin = require("firebase-admin");
const axios = require("axios");

admin.initializeApp();

exports.sendBroadcastNotification = onDocumentCreated("broadcasts/{docId}", async (event) => {
    const snap = event.data;
    if (!snap) return;

    const data = snap.data();
    if (!data) return;

    const title = data.title || "MindPilot Update";
    const body = data.body || "";
    const type = data.type || "update";

    const payload = {
        notification: {
            title: title,
            body: body,
        },
        data: {
            type: type,
            broadcastId: event.params.docId,
            click_action: "FLUTTER_NOTIFICATION_CLICK",
        },
        topic: "all_users",
    };

    try {
        await admin.messaging().send(payload);
    } catch (error) {
        console.error("Error:", error);
    }
});

// Curated pool of Chinese Wisdom & Proverbs
const CHINESE_WISDOM_POOL = [
    { q: "A journey of a thousand miles begins with a single step.", a: "Lao Tzu" },
    { q: "The man who moves a mountain begins by carrying away small stones.", a: "Confucius" },
    { q: "Do not fear going forward slowly; fear only standing still.", a: "Chinese Proverb" },
    { q: "He who asks is a fool for five minutes, but he who does not ask remains a fool forever.", a: "Chinese Proverb" },
    { q: "Be not afraid of growing slowly, be afraid only of standing still.", a: "Chinese Proverb" },
    { q: "Opportunities multiply as they are seized.", a: "Sun Tzu" },
    { q: "If you are planning for a year, sow rice; if you are planning for a decade, plant trees; if you are planning for a lifetime, educate people.", a: "Chinese Proverb" },
    { q: "To know the road ahead, ask those coming back.", a: "Chinese Proverb" },
    { q: "He who conquers himself is the mightiest warrior.", a: "Lao Tzu" },
    { q: "He who yields is strong; he who bends is victorious.", a: "Sun Tzu" },
    { q: "In the midst of chaos, there is also opportunity.", a: "Sun Tzu" },
    { q: "The best time to plant a tree was 20 years ago. The second best time is now.", a: "Chinese Proverb" },
    { q: "Learning is a treasure that will follow its owner everywhere.", a: "Chinese Proverb" },
    { q: "A wise man adapts himself to circumstances, as water shapes itself to the vessel that contains it.", a: "Chinese Proverb" },
    { q: "Control your emotions or they will control you.", a: "Chinese Proverb" },
    { q: "A book is like a garden carried in the pocket.", a: "Chinese Proverb" },
    { q: "When the wind of change blows, some build walls, while others build windmills.", a: "Chinese Proverb" },
    { q: "Tension is who you think you should be. Relaxation is who you are.", a: "Chinese Proverb" },
    { q: "Knowing others is intelligence; knowing yourself is true wisdom.", a: "Lao Tzu" },
    { q: "The supreme art of war is to subdue the enemy without fighting.", a: "Sun Tzu" },
    { q: "Great souls have wills; feeble ones have only wishes.", a: "Chinese Proverb" },
    { q: "If you want happiness for an hour, take a nap. If you want happiness for a lifetime, help someone else.", a: "Chinese Proverb" },
    { q: "A diamond with a flaw is worth more than a pebble without.", a: "Confucius" },
    { q: "Silence is a true friend who never betrays.", a: "Confucius" },
    { q: "The journey is the reward.", a: "Taoist Saying" },
    { q: "When you drink the water, remember the spring.", a: "Chinese Proverb" },
    { q: "Sorrow is the child of too much joy.", a: "Chinese Proverb" }
];

// Helper to fetch from one of the 6 public free APIs
async function fetchFromApi(sourceName) {
    const config = { timeout: 6000 };
    switch (sourceName) {
        case "ZenQuotes": {
            const response = await axios.get("https://zenquotes.io/api/random", config);
            if (!response.data || !response.data[0]) throw new Error("Empty response from ZenQuotes");
            return {
                quote: response.data[0].q,
                author: response.data[0].a || "Unknown",
                source: "ZenQuotes"
            };
        }
        case "FavQs": {
            const response = await axios.get("https://favqs.com/api/qotd", config);
            if (!response.data || !response.data.quote) throw new Error("Empty response from FavQs");
            return {
                quote: response.data.quote.body,
                author: response.data.quote.author || "Unknown",
                source: "FavQs"
            };
        }
        case "TypeFit": {
            const response = await axios.get("https://type.fit/api/quotes", config);
            if (!response.data || !Array.isArray(response.data)) throw new Error("Empty response from Type.fit");
            const quotes = response.data;
            const pick = quotes[Math.floor(Math.random() * quotes.length)];
            let cleanedAuthor = (pick.author || "Unknown").replace(", type.fit", "").trim();
            if (cleanedAuthor === "type.fit") cleanedAuthor = "Unknown";
            return {
                quote: pick.text,
                author: cleanedAuthor,
                source: "Type.fit"
            };
        }
        case "Forismatic": {
            const response = await axios.get("https://api.forismatic.com/api/1.0/?method=getQuote&format=json&lang=en", config);
            if (!response.data || !response.data.quoteText) throw new Error("Empty response from Forismatic");
            return {
                quote: response.data.quoteText,
                author: response.data.quoteAuthor || "Unknown",
                source: "Forismatic"
            };
        }
        case "Quotable": {
            const response = await axios.get("https://api.quotable.io/random", config);
            if (!response.data || !response.data.content) throw new Error("Empty response from Quotable");
            return {
                quote: response.data.content,
                author: response.data.author || "Unknown",
                source: "Quotable"
            };
        }
        case "DummyJSON": {
            const response = await axios.get("https://dummyjson.com/quotes/random", config);
            if (!response.data || !response.data.quote) throw new Error("Empty response from DummyJSON");
            return {
                quote: response.data.quote,
                author: response.data.author || "Unknown",
                source: "DummyJSON"
            };
        }
        case "BibleVerse": {
            const response = await axios.get("https://labs.bible.org/api/?passage=random&type=json", config);
            if (!response.data || !response.data[0]) throw new Error("Empty response from labs.bible.org");
            const data = response.data[0];
            return {
                quote: data.text,
                author: `${data.bookname} ${data.chapter}:${data.verse}`,
                source: "Holy Bible"
            };
        }
        default:
            throw new Error("Invalid API source: " + sourceName);
    }
}

exports.sendAutoInsights = onSchedule("every 5 minutes", async (event) => {
    try {
        const now = admin.firestore.Timestamp.now();

        // 1. Fetch Global Admin Settings for fallback timing
        const configDoc = await admin.firestore().collection("app_config").doc("settings").get();
        let defaultIntervalMs = 10800000; // Default 3 hours

        if (configDoc.exists) {
            const configData = configDoc.data();
            defaultIntervalMs = configData.quote_interval_ms || (configData.insightIntervalHours * 3600000) || 10800000;
        }

        // 2. Fetch all users who have an FCM token
        const usersSnap = await admin.firestore().collection("users")
            .where("fcmToken", "!=", "")
            .get();

        if (usersSnap.empty) {
            console.log("No users with FCM tokens found.");
            return;
        }

        // 3. Fetch a fresh quote from multiple sources for variety
        let quote = "Clarity comes when you stop seeking answers outside and start listening within.";
        let author = "Unknown";
        let source = "Unknown";

        // 35% chance to choose a Chinese wisdom proverb, 65% chance to query public APIs
        const useChineseWisdom = Math.random() < 0.35;

        if (useChineseWisdom) {
            console.log("Selecting quote from Curated Chinese Wisdom Pool...");
            const pick = CHINESE_WISDOM_POOL[Math.floor(Math.random() * CHINESE_WISDOM_POOL.length)];
            quote = pick.q;
            author = pick.a;
            source = "Chinese Wisdom Pool";
        } else {
            const apis = ["ZenQuotes", "FavQs", "TypeFit", "Forismatic", "Quotable", "DummyJSON", "BibleVerse"];
            const shuffledApis = apis.sort(() => Math.random() - 0.5);

            let success = false;
            for (const apiName of shuffledApis) {
                try {
                    console.log(`Attempting to fetch from API: ${apiName}...`);
                    const result = await fetchFromApi(apiName);
                    quote = result.quote;
                    author = result.author;
                    source = result.source;
                    success = true;
                    console.log(`Successfully fetched quote from ${apiName}`);
                    break;
                } catch (error) {
                    console.warn(`Failed to fetch from ${apiName}: ${error.message}. Trying next...`);
                }
            }

            if (!success) {
                console.error("All Quote APIs failed, using local combined pool.");
                const localBackupPool = [
                    ...CHINESE_WISDOM_POOL,
                    { q: "The only way to do great work is to love what you do.", a: "Steve Jobs" },
                    { q: "Success is not final, failure is not fatal.", a: "Winston Churchill" },
                    { q: "Believe you can and you're halfway there.", a: "Theodore Roosevelt" },
                    { q: "Your time is limited, so don't waste it.", a: "Steve Jobs" },
                    { q: "The best way to predict your future is to create it.", a: "Peter Drucker" },
                    { q: "Focus on being productive instead of busy.", a: "Tim Ferriss" },
                    { q: "The mind is everything. What you think you become.", a: "Buddha" },
                    { q: "Difficulties strengthen the mind, as labor does the body.", a: "Seneca" }
                ];
                const pick = localBackupPool[Math.floor(Math.random() * localBackupPool.length)];
                quote = pick.q || pick.quote;
                author = pick.a || pick.author;
                source = "Local Combined Backup";
            }
        }


        const promises = [];
        for (const doc of usersSnap.docs) {
            const userData = doc.data();
            const lastInsight = userData.lastInsightTime;
            const fcmToken = userData.fcmToken;

            // Per-user interval in hours (convert to Ms)
            const userIntervalHours = userData.insightIntervalHours;
            const userIntervalMs = (userIntervalHours && userIntervalHours > 0)
                ? (userIntervalHours * 3600000)
                : defaultIntervalMs;

            let shouldSend = false;
            if (!lastInsight) {
                shouldSend = true;
            } else {
                const diffMs = now.toMillis() - lastInsight.toMillis();
                if (diffMs >= userIntervalMs) {
                    shouldSend = true;
                }
            }

            if (shouldSend) {
                const payload = {
                    notification: {
                        title: "Daily Insight 💡",
                        body: quote,
                    },
                    data: {
                        type: "insight",
                        title: "Daily Insight",
                        body: quote,
                        author: author,
                        source: source,
                        click_action: "FLUTTER_NOTIFICATION_CLICK",
                    },
                    android: {
                        priority: "high",
                        notification: {
                            channelId: "mindpilot_notifications",
                            priority: "high",
                        },
                    },
                    apns: {
                        payload: {
                            aps: {
                                contentAvailable: true,
                                sound: "default",
                            },
                        },
                    },
                    token: fcmToken,
                };

                promises.push(
                    admin.messaging().send(payload)
                        .then(async () => {
                            console.log(`Sent to ${doc.id}, updating time.`);
                            await doc.ref.update({ lastInsightTime: now });
                        })
                        .catch((err) => {
                            console.error(`Error sending to ${doc.id}:`, err);
                        })
                );
            }
        }

        await Promise.all(promises);
        console.log(`Successfully processed ${promises.length} notifications.`);
    } catch (e) {
        console.error("Global AutoInsight Error:", e);
    }
});

// Super Admin list for registration alerts
const SUPER_ADMIN_EMAILS = [
    "laleyesolomon2@gmail.com",
    "solteqinnovationsltd@gmail.com",
];

exports.onUserCreated = onDocumentCreated("users/{userId}", async (event) => {
    const snap = event.data;
    if (!snap) return;

    const newUser = snap.data();
    if (!newUser) return;

    const userName = newUser.name || newUser.displayName || newUser.email || "Unknown";
    const userEmail = newUser.email || "No email";
    const userCountry = newUser.regCountry ? ` from ${newUser.regCountry}` : "";

    try {
        // Find super admin users and get their FCM tokens
        const promises = [];
        for (const adminEmail of SUPER_ADMIN_EMAILS) {
            const adminQuery = await admin.firestore()
                .collection("users")
                .where("email", "==", adminEmail)
                .limit(1)
                .get();

            if (adminQuery.empty) continue;

            const adminDoc = adminQuery.docs[0];
            const adminData = adminDoc.data();
            const fcmToken = adminData.fcmToken;

            if (!fcmToken) continue;

            const payload = {
                notification: {
                    title: "🆕 New User Registration",
                    body: `${userName} (${userEmail})${userCountry} just signed up!`,
                },
                data: {
                    type: "admin_alert",
                    title: "New User Registration",
                    body: `${userName} (${userEmail})${userCountry} just signed up!`,
                    click_action: "FLUTTER_NOTIFICATION_CLICK",
                },
                android: {
                    priority: "high",
                    notification: {
                        channelId: "mindpilot_notifications",
                        priority: "high",
                    },
                },
                apns: {
                    payload: {
                        aps: {
                            contentAvailable: true,
                            sound: "default",
                        },
                    },
                },
                token: fcmToken,
            };

            promises.push(
                admin.messaging().send(payload)
                    .then(() => console.log(`Registration alert sent to ${adminEmail}`))
                    .catch((err) => console.error(`Error sending to ${adminEmail}:`, err))
            );
        }

        await Promise.all(promises);
        console.log(`Processed ${promises.length} super admin registration alerts.`);
    } catch (e) {
        console.error("onUserCreated Error:", e);
    }
});


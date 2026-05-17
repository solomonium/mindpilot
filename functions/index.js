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
        
        // Randomly choose between ZenQuotes and Quotable
        const useZen = Math.random() > 0.5;
        let source = "Unknown";
        
        try {
            if (useZen) {
                console.log("Fetching from ZenQuotes...");
                const response = await axios.get("https://zenquotes.io/api/random");
                quote = response.data[0].q;
                author = response.data[0].a;
                source = "ZenQuotes";
            } else {
                console.log("Fetching from FavQs...");
                const response = await axios.get("https://favqs.com/api/qotd");
                quote = response.data.quote.body;
                author = response.data.quote.author || "Unknown";
                source = "FavQs";
            }
        } catch (error) {
            console.error("Primary Quote API Error, trying fallback:", error.message);
            // Fallback to the other API if one fails
            try {
                if (!useZen) {
                    const response = await axios.get("https://zenquotes.io/api/random");
                    quote = response.data[0].q;
                    author = response.data[0].a;
                    source = "ZenQuotes (Fallback)";
                } else {
                    const response = await axios.get("https://favqs.com/api/qotd");
                    quote = response.data.quote.body;
                    author = response.data.quote.author || "Unknown";
                    source = "FavQs (Fallback)";
                }
            } catch (fallbackError) {
                console.error("All Quote APIs failed, using local pool.");
                const quotes = [
                    {q: "The only way to do great work is to love what you do.", a: "Steve Jobs"},
                    {q: "Success is not final, failure is not fatal.", a: "Winston Churchill"},
                    {q: "Believe you can and you're halfway there.", a: "Theodore Roosevelt"},
                    {q: "Your time is limited, so don't waste it.", a: "Steve Jobs"},
                    {q: "The best way to predict your future is to create it.", a: "Peter Drucker"},
                    {q: "Focus on being productive instead of busy.", a: "Tim Ferriss"},
                    {q: "The mind is everything. What you think you become.", a: "Buddha"},
                    {q: "Difficulties strengthen the mind, as labor does the body.", a: "Seneca"}
                ];
                const pick = quotes[Math.floor(Math.random() * quotes.length)];
                quote = pick.q;
                author = pick.a;
                source = "Local Backup";
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

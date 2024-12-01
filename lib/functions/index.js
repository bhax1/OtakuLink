const functions = require("firebase-functions");
const admin = require("firebase-admin");

admin.initializeApp();

exports.sendFriendRequestNotification = functions.firestore
    .document('users/{userId}/notifications/{notificationId}')
    .onCreate(async (snap, context) => {
        const notificationData = snap.data();
        const userId = context.params.userId;
        const fromUserId = notificationData.fromUserId;

        // Get the user profile for sending the notification
        const userSnapshot = await admin.firestore().collection('users').doc(userId).get();
        const userProfile = userSnapshot.data();

        if (!userProfile || !userProfile.fcmToken) {
            console.log('User FCM token not found.');
            return null;
        }

        // Create a notification payload
        const payload = {
            notification: {
                title: 'New Friend Request',
                body: 'You have a new friend request!',
                sound: 'default',
            },
            data: {
                fromUserId: fromUserId,
                type: 'friend_request',
            },
        };

        // Send the push notification
        return admin.messaging().sendToDevice(userProfile.fcmToken, payload);
    });

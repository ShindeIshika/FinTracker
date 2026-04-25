/**
 * Import function triggers from their respective submodules:
 *
 * const {onCall} = require("firebase-functions/v2/https");
 * const {onDocumentWritten} = require("firebase-functions/v2/firestore");
 *
 * See a full list of supported triggers at https://firebase.google.com/docs/functions
 */
const { onRequest } = require("firebase-functions/v2/https");
const { initializeApp } = require("firebase-admin/app");
const { getFirestore } = require("firebase-admin/firestore");
const { getMessaging } = require("firebase-admin/messaging");

initializeApp();
const db = getFirestore();
const fcm = getMessaging();

// ─── Send notification to a user by their uid ───────────────────────────
async function sendToUser(uid, title, body) {
  try {
    const tokenSnap = await db.collection("fcm_tokens")
      .where("uid", "==", uid).get();
    if (tokenSnap.empty) return;

    const token = tokenSnap.docs[0].data().token;
    await fcm.send({
      token,
      notification: { title, body },
      android: { priority: "high" },
      apns: { payload: { aps: { sound: "default" } } },
    });
  } catch (e) {
    console.log("Failed to send to user:", uid, e.message);
  }
}

// ─── Bill Reminders (runs every day at 9 AM) ────────────────────────────
exports.billReminders = onRequest(async (req, res) => {
  const now = new Date();
  const billsSnap = await db.collection("bills").get();

  for (const doc of billsSnap.docs) {
    const bill = doc.data();
    const uid = bill.uid;
    if (!uid || !bill.nextDueDate) continue;

    const due = bill.nextDueDate.toDate();
    const diffDays = Math.ceil((due - now) / (1000 * 60 * 60 * 24));
    const name = bill.name || "Bill";
    const amount = bill.amount || "";

    if (diffDays === 7) {
      await sendToUser(uid,
        `📅 Bill Due in a Week: ${name}`,
        `₹${amount} is due on ${due.getDate()}/${due.getMonth()+1}. Plan ahead!`
      );
    } else if (diffDays === 3) {
      await sendToUser(uid,
        `⚠️ Bill Due Soon: ${name}`,
        `₹${amount} is due in 3 days. Don't forget!`
      );
    } else if (diffDays === 1) {
      await sendToUser(uid,
        `🔔 Bill Due Tomorrow: ${name}`,
        `₹${amount} is due tomorrow. Pay now to avoid penalties!`
      );
    } else if (diffDays === 0) {
      await sendToUser(uid,
        `❗ Bill Due Today: ${name}`,
        `₹${amount} is due TODAY. Tap to mark as paid.`
      );
    } else if (diffDays < 0) {
      await sendToUser(uid,
        `🔴 Overdue Bill: ${name}`,
        `₹${amount} is ${Math.abs(diffDays)} day(s) overdue! Pay immediately.`
      );
    }
  }
  res.send("OK");
});

// ─── Split Bill Reminders (runs every 3 days) ───────────────────────────
exports.splitBillReminders = onRequest(async (req, res) => {
  const billsSnap = await db.collection("split_bills").get();

  for (const doc of billsSnap.docs) {
    const bill = doc.data();
    const participants = bill.participants || [];
    const total = bill.total || 0;
    const share = participants.length > 0 ? total / participants.length : 0;
    const settlements = bill.userSettlements || {};

    for (const p of participants) {
      const uid = p.uid;
      if (!uid) continue;

      const paid = p.paid || 0;
      const balance = paid - share;

      // This person owes money
      if (balance < -0.5) {
        const status = settlements[uid]?.status;
        if (status !== "paid") {
          const owes = Math.abs(balance).toFixed(0);
          await sendToUser(uid,
            `💸 You still owe ₹${owes}`,
            `Don't forget to settle your share of "${bill.title}". Tap to pay!`
          );
        }
      }

      // This person is owed money
      else if (balance > 0.5) {
        let pendingCount = 0;
        let pendingAmount = 0;

        for (const debtor of participants) {
          const dPaid = debtor.paid || 0;
          const dBal = dPaid - share;
          if (dBal >= -0.01) continue;

          const dKey = debtor.uid
            ? debtor.uid
            : `manual_${(debtor.name || "unknown").replace(/ /g, "_")}`;
          const credRecvKey = `${uid}_recv_${dKey}`;
          const alreadyReceived =
            settlements[credRecvKey] || settlements[dKey]?.status === "paid";

          if (!alreadyReceived) {
            pendingCount++;
            pendingAmount += Math.abs(dBal);
          }
        }

        if (pendingCount > 0) {
          await sendToUser(uid,
            `💰 You're owed ₹${pendingAmount.toFixed(0)}`,
            `${pendingCount} person(s) still haven't paid for "${bill.title}". Give them a nudge!`
          );
        }
      }
    }
  }
  res.send("OK");
});

// ─── Budget Alerts (runs every day at 6 PM) ─────────────────────────────
exports.budgetAlerts = onRequest(async (req, res) => {
  const budgetsSnap = await db.collection("budgets").get();

  const persuasiveMessages = [
    (name, pct) => [`🚨 ${name} Budget at ${pct}%!`, `You're almost out! Spend wisely — every rupee saved today is a reward tomorrow. 🏆`],
    (name, pct) => [`⚠️ Warning: ${name} at ${pct}%`, `Just ${100 - pct}% left! Pull back now and treat yourself to something special at month end. 🎁`],
    (name, pct) => [`🔥 ${name} is burning fast (${pct}%)`, `Top savers stay under budget. You've got this — slow down and win the month! 🥇`],
  ];

  const exceededMessages = [
    (name, over) => [`🔴 ${name} Exceeded by ₹${over}!`, `Oops! You've gone over. The good news? You can reset next month — start fresh & stronger! 💪`],
    (name, over) => [`❌ Over Budget: ${name}`, `₹${over} over limit! Every rupee counts. Track smarter, save harder. 🎯`],
  ];

  for (const doc of budgetsSnap.docs) {
    const b = doc.data();
    const uid = b.uid;
    if (!uid || b.limit <= 0) continue;

    const spent = b.spent || 0;
    const limit = b.limit;
    const pct = Math.round((spent / limit) * 100);
    const name = b.name || b.category || "Budget";

    if (pct >= 100) {
      const over = (spent - limit).toFixed(0);
      const idx = Math.floor(Math.random() * exceededMessages.length);
      const [title, body] = exceededMessages[idx](name, over);
      await sendToUser(uid, title, body);
    } else if (pct >= 70) {
      const idx = Math.floor(Math.random() * persuasiveMessages.length);
      const [title, body] = persuasiveMessages[idx](name, pct);
      await sendToUser(uid, title, body);
    }
  }
  res.send("OK");
});

// ─── Savings Reminders (runs every 3 days) ──────────────────────────────
exports.savingsReminders = onRequest(async (req, res) => {
  const goalsSnap = await db.collection("savings_goals").get();

  const encouragements = [
    (title, pct, remaining) => [`🌟 Keep Going: ${title}`, `You're ${pct}% there! Just ₹${remaining} more to go. Future-you will thank you! 🙌`],
    (title, pct, remaining) => [`💰 Saving Streak: ${title}`, `${pct}% complete! Small steps = big wins. Add a little today — it all adds up! 📈`],
    (title, pct, remaining) => [`🎯 Goal Check: ${title}`, `₹${remaining} away from your dream! You're closer than you think. Keep it up! 🚀`],
  ];

  for (const doc of goalsSnap.docs) {
    const g = doc.data();
    const uid = g.uid;
    if (!uid || g.targetAmount <= 0) continue;

    const saved = g.savedAmount || 0;
    const target = g.targetAmount;
    const pct = Math.round((saved / target) * 100);
    const remaining = (target - saved).toFixed(0);
    const title = g.title || "Savings Goal";

    if (pct >= 100) {
      await sendToUser(uid,
        `🎉 Goal Achieved: ${title}!`,
        `You've saved ₹${target.toFixed(0)}! You're a savings champion! 🏆 Time to set a new goal!`
      );
    } else {
      const idx = Math.floor(Math.random() * encouragements.length);
      const [notifTitle, body] = encouragements[idx](title, pct, remaining);
      await sendToUser(uid, notifTitle, body);
    }
  }
  res.send("OK");
});



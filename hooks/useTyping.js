"use client";
import { useEffect, useState, useCallback, useRef } from "react";
import { subscribeToTyping } from "../lib/realtime";

const TYPING_TIMEOUT_MS = 3000; // how long before a peer is considered "stopped typing"
const SEND_THROTTLE_MS = 1500; // how often we broadcast "I'm typing" while the user keeps typing

/**
 * Broadcasts the current user's typing activity to others in a
 * conversation, and tracks which other users are currently typing
 * (auto-expiring them if no new event arrives within TYPING_TIMEOUT_MS).
 */
export function useTyping(conversationId, currentUserId, currentUserName) {
  const [typingUsers, setTypingUsers] = useState({}); // { [userId]: name }

  const channelRef = useRef(null);
  const timeoutsRef = useRef({}); // { [userId]: timeoutId }
  const lastSentAtRef = useRef(0);

  useEffect(() => {
    if (!conversationId) return;

    const { send, unsubscribe } = subscribeToTyping(conversationId, {
      onTyping: ({ userId, name, isTyping }) => {
        if (!userId || userId === currentUserId) return;

        if (timeoutsRef.current[userId]) {
          clearTimeout(timeoutsRef.current[userId]);
          delete timeoutsRef.current[userId];
        }

        if (isTyping) {
          setTypingUsers((prev) => ({ ...prev, [userId]: name || "someone" }));
          timeoutsRef.current[userId] = setTimeout(() => {
            setTypingUsers((prev) => {
              const next = { ...prev };
              delete next[userId];
              return next;
            });
            delete timeoutsRef.current[userId];
          }, TYPING_TIMEOUT_MS);
        } else {
          setTypingUsers((prev) => {
            const next = { ...prev };
            delete next[userId];
            return next;
          });
        }
      },
    });

    channelRef.current = { send };

    return () => {
      unsubscribe();
      Object.values(timeoutsRef.current).forEach(clearTimeout);
      timeoutsRef.current = {};
      setTypingUsers({});
    };
  }, [conversationId, currentUserId]);

  /**
   * Call this on every keystroke in MessageInput. Internally throttled
   * so it doesn't broadcast on every single character.
   */
  const notifyTyping = useCallback(() => {
    if (!channelRef.current) return;
    const now = Date.now();
    if (now - lastSentAtRef.current < SEND_THROTTLE_MS) return;
    lastSentAtRef.current = now;
    channelRef.current.send({ userId: currentUserId, name: currentUserName, isTyping: true });
  }, [currentUserId, currentUserName]);

  /**
   * Call this when the user sends the message or clears the input,
   * so peers immediately see "stopped typing" instead of waiting
   * for the timeout to expire.
   */
  const notifyStoppedTyping = useCallback(() => {
    if (!channelRef.current) return;
    lastSentAtRef.current = 0;
    channelRef.current.send({ userId: currentUserId, name: currentUserName, isTyping: false });
  }, [currentUserId, currentUserName]);

  return {
    typingUsers, // { [userId]: name } — others currently typing
    typingLabel: Object.values(typingUsers).join("، "),
    notifyTyping,
    notifyStoppedTyping,
  };
}

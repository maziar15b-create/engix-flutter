"use client";
import { useState, useRef } from "react";
import AttachmentPicker from "./AttachmentPicker";

const GOLD_LIGHT = "#FF3D63";
const GOLD = "#C50337";

export default function MessageInput(props) {
  var conversationId = props.conversationId;
  var replyingTo = props.replyingTo;
  var onCancelReply = props.onCancelReply;
  var onSend = props.onSend;
  var onTyping = props.onTyping;
  var sending = props.sending;

  var textState = useState("");
  var text = textState[0];
  var setText = textState[1];

  var attState = useState(null);
  var pendingAttachment = attState[0];
  var setPendingAttachment = attState[1];

  var uploadingState = useState(false);
  var uploading = uploadingState[0];
  var setUploading = uploadingState[1];

  var errorState = useState("");
  var error = errorState[0];
  var setError = errorState[1];

  var recordingState = useState(false);
  var recording = recordingState[0];
  var setRecording = recordingState[1];

  var mediaRecorderRef = useRef(null);
  var chunksRef = useRef([]);

  var hasText = text.trim().length > 0;
  var hasAttachment = !!pendingAttachment;
  var canSend = false;
  if (hasText || hasAttachment) {
    if (!sending && !uploading) canSend = true;
  }

  function handleChange(e) {
    setText(e.target.value);
    if (e.target.value.trim().length > 0) onTyping();
  }

  function handleKeyDown(e) {
    if (e.key === "Enter" && !e.shiftKey) {
      e.preventDefault();
      handleSend();
    }
  }

  function handleSend() {
    if (!canSend) return;
    var content = text.trim();
    var attachment = pendingAttachment;
    setText("");
    setPendingAttachment(null);
    setError("");
    onSend({ content: content, attachment: attachment }).catch(function () {
      setError("ارسال پیام ناموفق بود.");
    });
  }

  function startRecording() {
    setError("");
    if (!navigator.mediaDevices || !navigator.mediaDevices.getUserMedia) {
      setError("مرورگر شما از ضبط صدا پشتیبانی نمی‌کند.");
      return;
    }
    navigator.mediaDevices.getUserMedia({ audio: true }).then(function (stream) {
      var recorder = new MediaRecorder(stream);
      chunksRef.current = [];

      recorder.ondataavailable = function (e) {
        if (e.data.size > 0) chunksRef.current.push(e.data);
      };

      recorder.onstop = function () {
        var tracks = stream.getTracks();
        for (var i = 0; i < tracks.length; i++) tracks[i].stop();

        var blob = new Blob(chunksRef.current, { type: "audio/webm" });
        setUploading(true);
        uploadAttachmentVoice(blob, conversationId)
          .then(function (attachment) {
            setPendingAttachment(attachment);
            setUploading(false);
          })
          .catch(function (e) {
            setError(e.message);
            setUploading(false);
          });
      };

      mediaRecorderRef.current = recorder;
      recorder.start();
      setRecording(true);
    }).catch(function () {
      setError("دسترسی به میکروفون امکان‌پذیر نیست.");
    });
  }

  function stopRecording() {
    if (mediaRecorderRef.current && recording) {
      mediaRecorderRef.current.stop();
      setRecording(false);
    }
  }

  return (
    <div style={{ borderTop: "1px solid rgba(197,3,55,0.18)", paddingTop: 12 }}>
      {replyingTo && (
        <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", background: "#141318", border: "1px solid rgba(197,3,55,0.2)", borderRadius: 9, padding: "7px 11px", marginBottom: 8, fontSize: 12 }}>
          <div style={{ opacity: 0.85, overflow: "hidden", textOverflow: "ellipsis", whiteSpace: "nowrap", color: "#B7AF9C" }}>
            پاسخ به: {replyingTo.content || "پیوست"}
          </div>
          <button className="btn-ghost" style={{ padding: "2px 8px", fontSize: 11 }} onClick={onCancelReply}>×</button>
        </div>
      )}

      {pendingAttachment && (
        <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", background: "#141318", border: "1px solid rgba(197,3,55,0.2)", borderRadius: 9, padding: "7px 11px", marginBottom: 8, fontSize: 12 }}>
          <div style={{ color: "#B7AF9C" }}>{attachmentPreviewLabel(pendingAttachment)}</div>
          <button className="btn-ghost" style={{ padding: "2px 8px", fontSize: 11 }} onClick={function () { setPendingAttachment(null); }}>×</button>
        </div>
      )}

      <div style={{ display: "flex", alignItems: "flex-end", gap: 8 }}>
        <button
          className="btn-primary"
          style={{ padding: "9px 18px" }}
          disabled={!canSend}
          onClick={handleSend}
        >
          {sending ? "..." : "ارسال"}
        </button>

        <button
          className="btn-ghost"
          style={{
            padding: "9px 13px",
            background: recording ? "#E5484D" : undefined,
            color: recording ? "#fff" : undefined,
            borderColor: recording ? "#E5484D" : undefined,
          }}
          disabled={sending || uploading}
          onClick={recording ? stopRecording : startRecording}
          title={recording ? "پایان ضبط" : "ضبط پیام صوتی"}
        >
          {recording ? "⏹" : "🎤"}
        </button>

        <textarea
          className="field-input"
          placeholder={uploading ? "در حال آپلود..." : recording ? "در حال ضبط صدا..." : "پیام بنویسید..."}
          value={text}
          onChange={handleChange}
          onKeyDown={handleKeyDown}
          disabled={uploading || recording}
          rows={1}
          style={{ flex: 1, resize: "none", maxHeight: 120 }}
        />

        <AttachmentPicker
          conversationId={conversationId}
          disabled={sending || uploading || recording}
          onUploadStart={function () { setUploading(true); setError(""); }}
          onUploadComplete={function (attachment) { setPendingAttachment(attachment); setUploading(false); }}
          onUploadError={function (msg) { setError(msg); setUploading(false); }}
        />
      </div>

      {error && <div style={{ color: "#E5484D", fontSize: 12, marginTop: 6 }}>{error}</div>}
    </div>
  );
}

function attachmentPreviewLabel(attachment) {
  var icons = { image: "📷", pdf: "📄", word: "📝", voice: "🎤", location: "📍" };
  var icon = icons[attachment.type] || "📎";
  if (attachment.type === "location") return icon + " لوکیشن آماده ارسال";
  var name = (attachment.file_meta && attachment.file_meta.name) || "فایل آماده ارسال";
  return icon + " " + name;
}

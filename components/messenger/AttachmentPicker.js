"use client";
import { useRef, useState } from "react";
import { uploadAttachment } from "../../lib/upload";

export default function AttachmentPicker(props) {
  var conversationId = props.conversationId;
  var disabled = props.disabled;
  var onUploadStart = props.onUploadStart;
  var onUploadComplete = props.onUploadComplete;
  var onUploadError = props.onUploadError;

  var state = useState(false);
  var menuOpen = state[0];
  var setMenuOpen = state[1];

  var locState = useState(false);
  var locatingLocation = locState[0];
  var setLocatingLocation = locState[1];

  var imageInputRef = useRef(null);
  var pdfInputRef = useRef(null);
  var wordInputRef = useRef(null);

  function handleFilePicked(file) {
    if (!file) return;
    setMenuOpen(false);
    onUploadStart();
    uploadAttachment(file, conversationId)
      .then(function (attachment) {
        onUploadComplete(attachment);
      })
      .catch(function (e) {
        onUploadError(e.message);
      });
  }

  function handleShareLocation() {
    setMenuOpen(false);
    if (!navigator.geolocation) {
      onUploadError("مرورگر شما از ارسال لوکیشن پشتیبانی نمی‌کند.");
      return;
    }
    setLocatingLocation(true);
    onUploadStart();
    navigator.geolocation.getCurrentPosition(
      function (position) {
        var attachment = {
          type: "location",
          file_url: null,
          file_meta: {
            lat: position.coords.latitude,
            lng: position.coords.longitude,
          },
        };
        setLocatingLocation(false);
        onUploadComplete(attachment);
      },
      function () {
        setLocatingLocation(false);
        onUploadError("دسترسی به موقعیت مکانی امکان‌پذیر نیست. لطفاً دسترسی لوکیشن را در مرورگر فعال کنید.");
      },
      { enableHighAccuracy: true, timeout: 10000 }
    );
  }

  return (
    <div style={{ position: "relative" }}>
      <button
        className="btn-ghost"
        style={{ padding: "8px 12px" }}
        disabled={disabled || locatingLocation}
        onClick={function () { setMenuOpen(!menuOpen); }}
      >
        📎
      </button>

      {menuOpen && (
        <div
          style={{
            position: "absolute",
            bottom: "100%",
            left: 0,
            marginBottom: 6,
            background: "#101826",
            border: "1px solid rgba(255,255,255,0.1)",
            borderRadius: 8,
            padding: 6,
            minWidth: 150,
            maxWidth: "min(220px, 70vw)",
            zIndex: 20,
          }}
        >
          <MenuItem label="📷 عکس" onClick={function () { imageInputRef.current && imageInputRef.current.click(); }} />
          <MenuItem label="📄 فایل PDF" onClick={function () { pdfInputRef.current && pdfInputRef.current.click(); }} />
          <MenuItem label="📝 فایل Word" onClick={function () { wordInputRef.current && wordInputRef.current.click(); }} />
          <MenuItem label="📍 ارسال لوکیشن" onClick={handleShareLocation} />
        </div>
      )}

      <input
        ref={imageInputRef}
        type="file"
        accept="image/*"
        style={{ display: "none" }}
        onChange={function (e) { handleFilePicked(e.target.files[0]); }}
      />
      <input
        ref={pdfInputRef}
        type="file"
        accept="application/pdf"
        style={{ display: "none" }}
        onChange={function (e) { handleFilePicked(e.target.files[0]); }}
      />
      <input
        ref={wordInputRef}
        type="file"
        accept=".doc,.docx"
        style={{ display: "none" }}
        onChange={function (e) { handleFilePicked(e.target.files[0]); }}
      />
    </div>
  );
}

function MenuItem(props) {
  return (
    <div
      onClick={props.onClick}
      style={{ padding: "8px 10px", fontSize: 12.5, cursor: "pointer", borderRadius: 6, whiteSpace: "nowrap" }}
    >
      {props.label}
    </div>
  );
}

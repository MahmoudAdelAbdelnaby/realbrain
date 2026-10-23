package com.reelbrain.reelbrain

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class DownloadErrorsTest {
    private fun code(msg: String) = DownloadErrors.classify(msg)

    @Test
    fun classifiesYtDlpErrors() {
        assertEquals("NO_NETWORK", code("ERROR: Unable to download webpage: <urlopen error [Errno 7] No address associated with hostname>"))
        assertEquals("TIMEOUT", code("ERROR: [TikTok] 123: Read timed out."))
        assertEquals("LOGIN_REQUIRED", code("ERROR: [Instagram] C9xYz: Requested content is not available, rate-limit reached or login required"))
        assertEquals("NOT_FOUND", code("ERROR: [youtube] aB3dE: Video unavailable"))
        assertEquals("UNSUPPORTED_URL", code("ERROR: Unsupported URL: https://example.com/"))
        assertEquals("BLOCKED", code("ERROR: unable to download video data: HTTP Error 403: Forbidden"))
        assertEquals("UNKNOWN", code("something odd"))
    }

    // Real stderr from the S22 test run: the ffmpeg WARNING used to make all of these NOT_FOUND.
    private val warnings = "WARNING: ffmpeg-location /data/app/x/lib/arm64/libffmpeg.so does not exist! Continuing without ffmpeg\n" +
        "WARNING: [TikTok] The extractor is attempting impersonation, but no impersonate target is available.\n"

    @Test
    fun ignoresWarningLines() {
        assertEquals("BLOCKED", code(warnings + "ERROR: [TikTok] 7699: Unable to download webpage: HTTP Error 403: Forbidden"))
        assertEquals("EXTRACTOR", code(warnings + "ERROR: [TikTok] 7696: Video not available, status code 10240; please report this issue"))
        assertEquals("NO_NETWORK", code(warnings + "ERROR: [vm.tiktok] ZSg: Unable to download webpage: Remote end closed connection without response"))
        assertEquals("UNKNOWN", code(warnings + "ERROR: Unable to rename file: [Errno 2] No such file or directory: 'a.mp4.part'"))
    }

    @Test
    fun onlyNetworkishErrorsRetry() {
        assertTrue(DownloadErrors.isTransient("NO_NETWORK"))
        assertTrue(DownloadErrors.isTransient("BLOCKED"))
        assertFalse(DownloadErrors.isTransient("LOGIN_REQUIRED"))
        assertFalse(DownloadErrors.isTransient("NOT_FOUND"))
    }

    @Test
    fun parsesPrintLine() {
        val d = DownloadErrors.parsePrint("[download] 100%\n/data/files/reels/TikTok-7312.mp4|23.4\n")!!
        assertEquals("/data/files/reels/TikTok-7312.mp4", d.path)
        assertEquals(23.4, d.durationS!!, 0.001)
    }

    @Test
    fun missingDurationAndEmptyOutput() {
        assertNull(DownloadErrors.parsePrint("/x/a.mp4|NA")!!.durationS)
        assertNull(DownloadErrors.parsePrint(""))
    }
}

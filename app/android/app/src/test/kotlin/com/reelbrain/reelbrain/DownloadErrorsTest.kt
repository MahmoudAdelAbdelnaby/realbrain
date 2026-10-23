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

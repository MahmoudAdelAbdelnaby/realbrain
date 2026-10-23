package com.reelbrain.reelbrain

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class ShareTextTest {
    @Test
    fun bareUrl() = assertEquals(
        "https://www.instagram.com/reel/C9xYz/?igsh=abc",
        ShareText.extractUrl("https://www.instagram.com/reel/C9xYz/?igsh=abc"),
    )

    @Test
    fun urlInsideCaption() = assertEquals(
        "https://vm.tiktok.com/ZMabc123/",
        ShareText.extractUrl("Check out this video! https://vm.tiktok.com/ZMabc123/ #recipe"),
    )

    @Test
    fun arabicCaptionAndTrailingPunctuation() = assertEquals(
        "https://youtube.com/shorts/aB3dE?si=x1",
        ShareText.extractUrl("شوف الوصفة دي (https://youtube.com/shorts/aB3dE?si=x1)."),
    )

    @Test
    fun firstOfSeveral() = assertEquals(
        "https://a.example/1",
        ShareText.extractUrl("https://a.example/1 and https://b.example/2"),
    )

    @Test
    fun noLink() {
        assertNull(ShareText.extractUrl("just some text"))
        assertNull(ShareText.extractUrl(null))
    }
}

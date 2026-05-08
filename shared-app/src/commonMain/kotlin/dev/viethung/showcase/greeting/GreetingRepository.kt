package dev.viethung.showcase.greeting

interface GreetingRepository {
    suspend fun getGreeting(id: Long = 1L): String
}

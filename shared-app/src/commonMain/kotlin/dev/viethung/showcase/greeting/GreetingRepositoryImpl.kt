package dev.viethung.showcase.greeting

import dev.viethung.core.db.AppDatabase

class GreetingRepositoryImpl(
    private val database: AppDatabase,
) : GreetingRepository {
    override suspend fun getGreeting(id: Long): String =
        database.greetingQueries.selectById(id).executeAsOne()
}

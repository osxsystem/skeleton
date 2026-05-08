package dev.viethung.showcase.greeting

class GetGreetingUseCase(
    private val repository: GreetingRepository,
) {
    @Throws(Exception::class)
    suspend operator fun invoke(id: Long = 1L): String = repository.getGreeting(id)
}

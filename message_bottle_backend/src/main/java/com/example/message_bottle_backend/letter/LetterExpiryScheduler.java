package com.example.message_bottle_backend.letter;

import lombok.RequiredArgsConstructor;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.context.annotation.Configuration;
import org.springframework.scheduling.annotation.EnableScheduling;
import org.springframework.scheduling.annotation.Scheduled;

/**
 * 만료 스케줄러. 만료 판단은 조회·변경 API에서도 하므로 이 스케줄러의 실행 시점에 의존하지 않는다.
 */
@Configuration
@EnableScheduling
@RequiredArgsConstructor
@ConditionalOnProperty(name = "letter.expiry-scheduler.enabled", havingValue = "true", matchIfMissing = true)
public class LetterExpiryScheduler {

    private final SeaService seaService;

    @Scheduled(fixedDelayString = "${letter.expiry-scheduler.delay-ms:60000}")
    public void expire() {
        // 수신자마다 별도 트랜잭션으로 정리해서 한 명의 실패가 다른 사람에게 번지지 않게 한다.
        for (Long receiverId : seaService.receiversWithExpired()) {
            seaService.normalize(receiverId);
        }
    }
}

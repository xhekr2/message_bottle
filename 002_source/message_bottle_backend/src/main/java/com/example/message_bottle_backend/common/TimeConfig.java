package com.example.message_bottle_backend.common;

import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

import java.time.Clock;

@Configuration
public class TimeConfig {
    /** 시간과 만료 판단은 서버 시간 기준. 테스트에서 교체할 수 있게 빈으로 둔다. */
    @Bean
    Clock clock() {
        return Clock.systemDefaultZone();
    }
}

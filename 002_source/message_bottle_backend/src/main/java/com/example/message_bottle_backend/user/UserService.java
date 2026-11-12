package com.example.message_bottle_backend.user;

import com.example.message_bottle_backend.common.ApiException;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
@RequiredArgsConstructor
public class UserService {

    private final UserRepository userRepository;
    private final UserSettingsRepository settingsRepository;

    /** 내 바다를 공개/비공개로 바꾼다. 바꿀 수 있는 것은 로그인한 본인의 바다뿐이다. */
    @Transactional
    public SeaVisibilityResponse changeSeaVisibility(Long userId, SeaVisibility visibility) {
        User user = userRepository.findById(userId)
                .orElseThrow(() -> new ApiException(HttpStatus.UNAUTHORIZED, "존재하지 않는 사용자입니다."));
        user.changeSeaVisibility(visibility);
        return new SeaVisibilityResponse(user.getSeaVisibility());
    }

    /** 내 화면 설정. 아직 바꾼 적이 없으면 기본값을 돌려준다. */
    @Transactional(readOnly = true)
    public UserSettingsResponse getSettings(Long userId) {
        return settingsRepository.findByUserId(userId)
                .map(UserSettingsResponse::of)
                .orElseGet(UserSettingsResponse::defaults);
    }

    /**
     * 내 화면 설정을 바꾼다. 바꿀 수 있는 것은 로그인한 본인의 설정뿐이다.
     * 처음 바꿀 때 행을 만들며, 같은 사용자의 동시 요청이 행을 두 번 만들지 않도록 사용자 행을 잠근다.
     */
    @Transactional
    public UserSettingsResponse changeSettings(Long userId, UserSettingsRequest request) {
        User user = userRepository.findByIdForUpdate(userId)
                .orElseThrow(() -> new ApiException(HttpStatus.UNAUTHORIZED, "존재하지 않는 사용자입니다."));
        UserSettings settings = settingsRepository.findByUserId(userId)
                .orElseGet(() -> settingsRepository.save(new UserSettings(user)));
        settings.change(request.seaTone(), request.textStep(), request.idleSeconds(), request.waveType());
        return UserSettingsResponse.of(settings);
    }
}

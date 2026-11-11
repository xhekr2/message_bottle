package com.example.message_bottle_backend.user;

import com.example.message_bottle_backend.common.ApiException;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.PageRequest;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;
import java.util.regex.Pattern;

@RestController
@RequestMapping("/api/users")
@RequiredArgsConstructor
public class UserSearchController {

    private static final Pattern QUERY = Pattern.compile("[A-Za-z0-9]{1,20}");
    private static final int LIMIT = 20;

    private final UserRepository userRepository;

    /** 받는 사람 검색: 부분 일치, 대소문자 구분, 아이디만 반환한다. */
    @GetMapping("/search")
    public List<UserSearchResponse> search(@RequestParam("username") String username) {
        if (!QUERY.matcher(username).matches()) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "검색어는 영문, 숫자 1~20자로 입력해주세요.");
        }
        return userRepository.findByUsernameContainingOrderByUsernameAsc(username, PageRequest.of(0, LIMIT)).stream()
                .map(u -> new UserSearchResponse(u.getUsername()))
                .toList();
    }
}

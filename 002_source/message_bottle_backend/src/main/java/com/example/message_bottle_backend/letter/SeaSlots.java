package com.example.message_bottle_backend.letter;

import java.util.HashSet;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Set;

/**
 * 바다의 유리병 자리 규칙. 자리는 0~10의 11곳이고 떠 있는 편지는 최대 10개이므로 항상 한 곳 이상이 비어 있다.
 * 주인이 보는 화면과 방문자가 보는 화면이 같은 규칙으로 자리를 정하도록 한곳에 둔다.
 */
public final class SeaSlots {

    public static final int COUNT = 11;

    private SeaSlots() {
    }

    public static boolean valid(Integer slot) {
        return slot != null && slot >= 0 && slot < COUNT;
    }

    /**
     * 떠 있는 편지([floating], 발송 순)마다 자리를 정한다. 저장된 자리가 올바르고 겹치지 않으면 그대로 쓰고,
     * 자리가 없는 편지(새로 떠오른 편지)는 비어 있는 가장 앞 자리에 놓는다.
     */
    public static Map<Long, Integer> resolve(List<Letter> floating) {
        Map<Long, Integer> result = new LinkedHashMap<>();
        Set<Integer> used = new HashSet<>();
        for (Letter l : floating) {
            Integer slot = l.getSeaSlot();
            if (valid(slot) && used.add(slot)) {
                result.put(l.getId(), slot);
            }
        }
        for (Letter l : floating) {
            if (result.containsKey(l.getId())) {
                continue;
            }
            int slot = 0;
            while (used.contains(slot)) {
                slot++;
            }
            if (slot >= COUNT) {
                break; // 수용량(10개)을 넘는 편지는 없으므로 여기에 오지 않는다
            }
            used.add(slot);
            result.put(l.getId(), slot);
        }
        return result;
    }
}

from tmux_picker import quickjump


def test_assign_tags_uses_two_chars_for_small_counts():
    sessions = ["a", "b", "c"]

    result = quickjump.assign_tags(sessions)

    assert [tag for _, tag in result] == ["ff", "fj", "fd"]


def test_assign_tags_pairs_are_unique():
    sessions = [f"s{i}" for i in range(50)]

    result = quickjump.assign_tags(sessions)

    tags = [tag for _, tag in result]
    assert len(set(tags)) == len(tags)
    assert all(len(tag) == 2 for tag in tags)


def test_assign_tags_preserves_input_order():
    sessions = ["first", "second", "third"]

    result = quickjump.assign_tags(sessions)

    assert [name for name, _ in result] == sessions


def test_assign_tags_scales_to_three_chars_past_two_char_capacity():
    sessions = [f"s{i}" for i in range(600)]  # > 24**2 == 576

    result = quickjump.assign_tags(sessions)

    tags = [tag for _, tag in result]
    assert all(len(tag) == 3 for tag in tags)
    assert len(set(tags)) == len(tags)


def test_assign_tags_empty_list():
    assert quickjump.assign_tags([]) == []

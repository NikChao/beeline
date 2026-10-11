require "test_helper"

class MarkTest < ActiveSupport::TestCase
  test "points are rounded and path data drawn from them" do
    mark = drafts(:letter_first).marks.create!(kind: "stroke", color: "green", points: [ [ "1.234", 2 ], [ 3, 4.56 ] ])

    assert_equal [ [ 1.2, 2.0 ], [ 3.0, 4.6 ] ], mark.points
    assert_equal "M1.2 2 L3 4.6", mark.path_data
  end

  test "words need text and a single point" do
    assert drafts(:letter_first).marks.build(kind: "word", color: "red", points: [ [ 10, 10 ] ], text: "tighter").valid?
    assert_not drafts(:letter_first).marks.build(kind: "word", color: "red", points: [ [ 10, 10 ] ]).valid?
  end

  test "only known pens and inks" do
    assert_not drafts(:letter_first).marks.build(kind: "spray", color: "red", points: [ [ 1, 1 ], [ 2, 2 ] ]).valid?
    assert_not drafts(:letter_first).marks.build(kind: "line", color: "blue", points: [ [ 1, 1 ], [ 2, 2 ] ]).valid?
  end

  test "flat points are paired up" do
    mark = drafts(:letter_first).marks.create!(kind: "line", color: "yellow", points: [ 1, 2, 3, 4 ])

    assert_equal [ [ 1.0, 2.0 ], [ 3.0, 4.0 ] ], mark.points
  end

  test "lines need two points" do
    assert_not drafts(:letter_first).marks.build(kind: "line", color: "red", points: [ [ 1, 1 ] ]).valid?
    assert_not drafts(:letter_first).marks.build(kind: "line", color: "red", points: "nonsense").valid?
  end
end

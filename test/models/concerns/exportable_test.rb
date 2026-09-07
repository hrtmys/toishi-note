require "test_helper"

class ExportableTest < ActiveSupport::TestCase
  # A minimal stand-in, since every real Exportable includer (Note, Folder,
  # Notebook) validates its name/title as present — this exercises the
  # empty-after-sanitizing fallback those can never actually hit.
  class FakeRecord
    include Exportable

    attr_accessor :export_display_name_value

    def initialize(value)
      @export_display_name_value = value
    end

    private

    def export_display_name
      @export_display_name_value
    end
  end

  test "falls back to untitled when the name is blank" do
    assert_equal "untitled", FakeRecord.new("   ").export_basename
  end

  test "replaces filesystem-unsafe characters instead of dropping them" do
    assert_equal "a_b_c", FakeRecord.new("a/b:c").export_basename
  end

  test "truncates a very long name" do
    long_name = "a" * 100
    assert_equal 60, FakeRecord.new(long_name).export_basename.length
  end

  test "collapses a name of only dots so it can never become a .. path segment" do
    assert_equal "_", FakeRecord.new("..").export_basename
    assert_equal "_", FakeRecord.new("...").export_basename
  end

  test "collapses embedded runs of dots too, e.g. a name like '../etc'" do
    basename = FakeRecord.new("../etc").export_basename
    assert_not_includes basename, ".."
  end
end

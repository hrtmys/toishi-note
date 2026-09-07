require "test_helper"

# G-3 (audit): before_create used to read siblings.maximum(:position)
# without locking the parent, so two concurrent creates under the same
# parent could both compute the same next position. This drives real
# concurrent creates through separate threads (each gets its own DB
# connection from the pool), which needs transactional fixtures off —
# they'd otherwise force every thread onto the single connection/
# transaction the test runs in and hide the very race being tested. The
# test cleans up what it creates instead.
class PositionedConcurrencyTest < ActiveSupport::TestCase
  self.use_transactional_tests = false

  test "concurrent creates under the same parent never collide on position" do
    notebook = users(:one).notebooks.create!(name: "Concurrency Notebook")

    barrier = Concurrent::CyclicBarrier.new(4)
    threads = 4.times.map do
      Thread.new do
        barrier.wait # line every thread up to hit before_create as close together as possible
        notebook.folders.create!(name: "Racer")
      end
    end
    created = threads.map(&:value)

    positions = created.map(&:position)
    assert_equal positions.uniq.sort, positions.sort, "no two concurrently-created siblings should share a position"
    assert_equal [ 1, 2, 3, 4 ], positions.sort
  ensure
    notebook&.destroy!
  end
end

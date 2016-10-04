class DockingStation

  def initialize
    @bikes = []
    @capacity = 5
  end

  def add_bike
    bike = Bike.new
    if bike.working?
      @bikes << bike
    else
      raise 'Bike Broken'
    end
  end

end


class Bike
  def initialize
    @working = true
  end

  def working?
    @working
  end

  def report_broken
    switch_state
  end

  def fix_bike
    switch_state
  end

  private

  def switch_state
    @working = !@working
  end
end

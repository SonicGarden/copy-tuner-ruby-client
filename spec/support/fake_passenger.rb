class FakePassenger
  def initialize
    @handlers = {}
  end

  def on_event(name, &handler)
    @handlers[name] ||= []
    @handlers[name] << handler
  end

  def call_event(name, *args)
    @handlers[name]&.each do |handler|
      handler.call(*args)
    end
  end

  def become_master
    $0 = 'PassengerApplicationSpawner'
  end

  def spawn
    $0 = 'PassengerFork'
    call_event(:starting_worker_process, true)
  end
end

extends Code

var queue: Array[Callable] = []
var mutex: Mutex
var semaphore: Semaphore
var threads: Array[Thread] = []
var exit_thread: bool = false

func _init():
	mutex = Mutex.new()
	semaphore = Semaphore.new()
	
	for i in OS.get_processor_count() - 2:
		var t = Thread.new()
		t.start(_thread_loop)
		threads.append(t)

func add_task(task: Callable):
	mutex.lock()
	queue.push_back(task)
	mutex.unlock()
	semaphore.post() 

func _thread_loop():
	while true:
		semaphore.wait() 
		
		mutex.lock()
		if exit_thread:
			mutex.unlock()
			return 
		
		if queue.is_empty():
			mutex.unlock()
			continue
			
		var task = queue.pop_front()
		mutex.unlock()
		
		if task.is_valid():
			task.call()

func _exit_tree():
	mutex.lock()
	exit_thread = true
	mutex.unlock()
	
	for i in threads.size():
		semaphore.post()
		
	for t in threads:
		t.wait_to_finish()

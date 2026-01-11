## Manages a pool of threads for executing tasks.
extends Code

## Queue of tasks to execute.
var queue: Array[Callable] = []
## Mutex for thread-safe access to the queue.
var mutex: Mutex
## Semaphore to signal available work.
var semaphore: Semaphore
## Array of active threads.
var threads: Array[Thread] = []
## Flag to signal threads to exit.
var exit_thread: bool = false

## Initializes the thread pool.
func _init():
	mutex = Mutex.new()
	semaphore = Semaphore.new()
	
	# Match thread count to CPU cores (e.g., 8 threads)
	for i in OS.get_processor_count() - 2:
		var t = Thread.new()
		t.start(_thread_loop)
		threads.append(t)

func add_task(task: Callable):
	mutex.lock()
	queue.push_back(task)
	mutex.unlock()
	semaphore.post() # Wake up one thread

## Main loop for worker threads to process tasks.
func _thread_loop():
	while true:
		semaphore.wait() # Sleep until work is available
		
		mutex.lock()
		if exit_thread:
			mutex.unlock()
			return # Exit the loop and kill the thread
		
		if queue.is_empty():
			mutex.unlock()
			continue
			
		var task = queue.pop_front()
		mutex.unlock()
		
		# Execute the Callable
		if task.is_valid():
			task.call()

func _exit_tree():
	# Clean shutdown: prevent the hang you were worried about
	mutex.lock()
	exit_thread = true
	mutex.unlock()
	
	# Wake up all threads so they can see the 'exit_thread' flag
	for i in threads.size():
		semaphore.post()
		
	# Wait for threads to finish their current task and close
	for t in threads:
		t.wait_to_finish()

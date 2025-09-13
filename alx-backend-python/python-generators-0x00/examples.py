import time
from functools import wraps

def timer(func):
    @wraps(func)  # This is the magic line!
    def wrapper(*args, **kwargs):
        t1 = time.time()
        result = func(*args, **kwargs) # Call the original function
        t2 = time.time()
        print(f"Function {func.__name__} took {t2 - t1:.4f} seconds to run.")
        return result
    return wrapper

@timer
def long_running_task():
    """This function simulates a long-running task."""
    time.sleep(2)
    print("Task completed!")

long_running_task()

# Now we can check the original function's name and docstring
print(f"Original function name: {long_running_task.__name__}")
print(f"Original function docstring: {long_running_task.__doc__}")

##################
class MyContextManager:
    def __init__(self):
        print("Initializing the context manager.")

    def __enter__(self):
        print("Entering the 'with' block.")
        return self

    def __exit__(self, exc_type, exc_val, exc_tb):
        print("Exiting the 'with' block.")
        if exc_type:
            print(f"An exception of type {exc_type.__name__} occurred.")
        # Returning True here would suppress the exception
        # return False

# Using the custom context manager
print("Before the 'with' statement.")
with MyContextManager() as manager:
    print("Inside the 'with' block.")
print("After the 'with' statement.")

class WorkingDirectoryManager:

    def __init__(self,new_dir):

        print("Initializing the context manager.")
        self.new_directory = new_dir



    def __enter__(self):

        print("Entering the 'with' block.")
        self.old_dir = os.getcwd()
        os.chdir(old_dir)
        os.chdir(self.new_directory)

        return self



    def __exit__(self, exc_type, exc_val, exc_tb):

        print("Exiting the 'with' block.")
        os.chdir(self.old_dir)

        if exc_type:

            print(f"An exception of type {exc_type.__name__} occurred.")

###### asynchronous programming
import asyncio
import time

# This is a coroutine because of 'async'
async def say_hello():
    print("Hello from coroutine!")
    # 'await' here pauses this coroutine and lets the event loop run other things
    await asyncio.sleep(1)
    print("... and I'm back!")

# This is a normal, synchronous function
def say_goodbye():
    print("Goodbye from a regular function.")

# Main entry point to run the coroutines
async def main():
    # Use await to run our coroutine
    await say_hello()
    
# We run the coroutine using the event loop.
asyncio.run(main())

say_goodbye()




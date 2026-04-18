from fastapi import FastAPI
import uvicorn

app = FastAPI(title="Face Landmark Detection API")

@app.get("/")
def read_root():
    return {"message": "Backend is running!"}

if __name__ == "__main__":
    uvicorn.run("main:app", host="0.0.0.0", port=8000, reload=True)

import httpx
import asyncio

async def main():
    url = "http://192.168.1.102:8080/api/devices/71f118b4e8f86e22/queue"
    headers = {
        'Content-Type': 'application/json', 
        'Grpc-Metadata-Authorization': 'Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJhcGlfa2V5X2lkIjoiNzNlZTI0M2YtZjczYi00ODU1LWJkZWYtNWViYjVmZjZiMGZjIiwiYXVkIjoiYXMiLCJpc3MiOiJhcyIsIm5iZiI6MTc3MDgzODkyOSwic3ViIjoiYXBpX2tleSJ9.NmWQ_FKMEXcZ0XdeblO3DEAe-Cp7r1GSp3-r8rPtAKg'
    }
    json_data = {'deviceQueueItem': {'confirmed': False, 'fPort': 10, 'data': 'U1RPUA=='}}
    
    print(f"Sending request to {url}...")
    async with httpx.AsyncClient() as client:
        try:
            r = await client.post(url, json=json_data, headers=headers)
            print(f"Status Code: {r.status_code}")
            print(f"Response Body: {r.text}")
        except Exception as e:
            print(f"Error: {e}")

if __name__ == "__main__":
    asyncio.run(main())

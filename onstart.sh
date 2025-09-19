#!/bin/bash

apt update && apt install -y git wget curl ffmpeg

cd /workspace
git clone https://github.com/MaxBabenko/edge-tts.git
cd edge-tts

sed -i 's/demo.launch(show_api=False)/demo.launch(server_name="0.0.0.0", server_port=7860, show_api=True)/' app.py
sed -i 's/demo.queue(default_concurrency_limit=50)/demo.queue(default_concurrency_limit=50, api_open=True)/' app.py

pip install -r requirements.txt

# Pre-warm edge-tts by fetching available voices (this will cache them)
python -c "
import asyncio
import edge_tts

async def preload_voices():
    print('Pre-loading Edge TTS voices...')
    voices = await edge_tts.list_voices()
    print(f'Loaded {len(voices)} voices successfully!')
    
    # Test a quick TTS to ensure everything works
    print('Testing TTS functionality...')
    test_tts = edge_tts.Communicate('Hello, this is a test.', 'en-US-AriaNeural')
    with open('/tmp/test.mp3', 'wb') as f:
        async for chunk in test_tts.stream():
            if chunk['type'] == 'audio':
                f.write(chunk['data'])
    print('TTS test successful!')

asyncio.run(preload_voices())
"

# Create a startup script for manual use if needed
cat > /workspace/start_edgetts.sh << 'EOF'
#!/bin/bash
cd /workspace/Edge-TTS-Text-to-Speech
python app.py
EOF

chmod +x /workspace/start_edgetts.sh

echo "Setup complete! Starting Edge TTS service automatically..."

# Start the Edge TTS service automatically
cd /workspace/Edge-TTS-Text-to-Speech
nohup python app.py > /workspace/edgetts.log 2>&1 &

echo "Edge TTS service is starting in the background..."

# Wait a moment and check if service started successfully
sleep 5
if pgrep -f "python app.py" > /dev/null; then
    echo "✅ Service is running successfully!"
else
    echo "❌ Service may have failed to start. Check logs: cat /workspace/edgetts.log"
fi

这些音频由本项目的 `tools/generate_audio.py` 使用 Python 标准库、正弦波和固定随机种子的滤波噪声原创合成，未使用任何外部录音、采样或音乐；运行该脚本可复现全部 22050 Hz、16 位 PCM WAV 文件。
`forest_ambience.wav` 是 14 秒的立体声林地循环，使用周期稳态滤波噪声与整周期柔和和声实现首尾衔接，其余文件是短交互音效；`ForestAudio` 在运行时设置 WAV 循环并以保守音量播放。

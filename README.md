# discord-video-compressor

![Windows](https://img.shields.io/badge/OS-Windows-blue)
![Python](https://img.shields.io/badge/Python-3.x-blue)
![FFmpeg](https://img.shields.io/badge/FFmpeg-Required-brightgreen)

指定された目標ファイルサイズ（MB単位）に動画ファイルをH.264コーデックで圧縮するWindows用バッチスクリプト  
FFmpegを利用して圧縮を行い、discordで動画を送信する際の容量の制限を回避する

## requirements

* **Windows**
* **Python 3.x**: コマンドプロンプトから `python` コマンドが実行できるようにPATHが設定されていること
* **FFmpeg**: `ffmpeg.exe` と `ffprobe.exe` がインストールされており、コマンドプロンプトからこれらのコマンドが実行できるようにPATHが設定されていること
    * FFmpeg公式サイト: [https://ffmpeg.org/download.html](https://ffmpeg.org/download.html)
    * Windows向けのビルド例: [Gyan.dev](https://www.gyan.dev/ffmpeg/builds/) や [BtbN/FFmpeg-Builds](https://github.com/BtbN/FFmpeg-Builds/releases)

## usage
* `video-compressor.bat`をダウンロード

* **「送る」メニューへの登録**
    1.   `%AppData%\Microsoft\Windows\SendTo` に`video-compressor.bat`を配置する
    2.  圧縮したい動画ファイルを右クリックし、「送る(N)」メニューから`video-compressor.bat`を選択する
    3.  [詳細](https://qiita.com/tatesuke/items/63971d0d1ce1f4f1c20c#bat%E3%83%95%E3%82%A1%E3%82%A4%E3%83%AB%E3%81%ABpython%E3%82%B9%E3%82%AF%E3%83%AA%E3%83%97%E3%83%88%E3%82%92%E6%9B%B8%E3%81%8F)

* `Enter target size per file in MB (e.g., 50):` のようなメッセージが表示されるので、圧縮後の各ファイルの目標サイズをMB単位で数値で入力し、Enterキーを押す

* 処理が完了すると、コマンドプロンプトに結果が表示される
* 圧縮されたファイルは、元の動画ファイルと同じフォルダに出力される

## more settings
* `H264_PRESET = "medium"`: libx264のエンコードプリセット、速度と品質のバランスを調整可能
    * 例: `ultrafast`, `superfast`, `veryfast`, `faster`, `fast`, `medium`, `slow`, `slower`, `veryslow`
* `MIN_VIDEO_BITRATE_KBPS = 100`: 計算されたビデオビットレートがこの値を下回る場合、この値が使用される
* `ASSUMED_AUDIO_BITRATE_KBPS = 128`: ビデオビットレートを計算する際に、音声部分のビットレートとして仮定する値（実際の音声はコピーされる）

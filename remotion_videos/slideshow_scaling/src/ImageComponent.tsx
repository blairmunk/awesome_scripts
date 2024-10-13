import React from 'react';
import { AbsoluteFill, Img, interpolate, useCurrentFrame, useVideoConfig } from 'remotion';

interface ImageProps {
  src: string;
  durationInSeconds: number;
}

export const ImageComponent: React.FC<ImageProps> = ({ src, durationInSeconds }) => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();

  // Рассчитываем начальный и конечный фреймы
  const startFrame = 0;
  const endFrame = Math.floor(durationInSeconds * fps);

  // Линейная интерполяция масштаба
  const scale = interpolate(frame, [startFrame, endFrame], [1, 1.1]);

  // Анимация прозрачности для плавного перехода
  const transitionDuration = 3; // Длительность перехода в секундах
  const transitionStart = startFrame;
  const transitionEnd = transitionStart + Math.floor(transitionDuration * fps);

  const opacity = interpolate(
    frame,
    [transitionStart, transitionEnd],
    [0, 1],
    {
      extrapolateLeft: 'clamp',
      extrapolateRight: 'clamp',
    }
  );


  return (
    <AbsoluteFill style={{ backgroundColor: 'transparent' }}>
      <div style={{
        position: 'absolute',
        top: 0,
        left: 0,
        right: 0,
        bottom: 0,
        overflow: 'hidden',
      }}>
        <Img
          src={src}
          style={{
            width: '100%',
            height: '100%',
            objectFit: 'cover',
            transform: `scale(${scale})`,
            opacity,
          }}
        />
      </div>
    </AbsoluteFill>
  );
};

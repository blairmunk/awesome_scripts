import React from 'react';
import { Composition, Sequence, Video } from 'remotion';
import { ImageComponent } from './ImageComponent';
import img1 from './assets/img/1.jpg';
import img2 from './assets/img/2.jpg';
import img3 from './assets/img/3.jpg';
import img4 from './assets/img/4.jpg';
import img5 from './assets/img/5.jpg';
import img6 from './assets/img/6.jpg';
import img7 from './assets/img/7.jpg';
import img8 from './assets/img/8.jpg';
import img9 from './assets/img/9.jpg';
import img10 from './assets/img/10.jpg';
import img11 from './assets/img/11.jpg';
import img12 from './assets/img/12.jpg';
import img13 from './assets/img/13.jpg';
import img14 from './assets/img/14.jpg';
import img15 from './assets/img/15.jpg';



const images = [
  img1,
  img2,
  img3,
  img4,
  img5,
  img6,
  img7,
  img8,
  img9,
  img10,
  img11,
  img12,
  img13,
  img14,
  img15,
];

export const MyVideo: React.FC = () => {
  return (
    <div style={{ flex: 1 }}>
      {images.map((image, index) => (
        <Sequence
          from={index * 240} // Начало каждой последовательности через 8 секунд
          duration={240} // Длительность каждой последовательности - 8 секунд
          name={`image-${index}`}
        >
          <ImageComponent src={image} durationInSeconds={8} />
        </Sequence>
      ))}
    </div>
  );
};

export const RemotionVideo = () => {
  return (
    <Composition
      id="MyVideo"
      component={MyVideo}
      durationInFrames={240 * images.length} // Общая длительность видео
      fps={30}
      width={1920}
      height={1080}
    />
  );
};
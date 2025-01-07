Creating a convincing pixelated aesthetic for 3D models can be computationally expensive, especially when targeting mobile platforms. Traditional methods like mesh manipulation, voxel generation, or high-resolution pixelation often struggle with performance, particularly with complex scenes or high polygon counts.

To address this challenge, I've developed a performant toon shader designed to emulate a pixelated look on mobile devices without sacrificing frame rate. This shader employs several key techniques:


https://github.com/user-attachments/assets/47ce21f1-6e16-4693-a474-f99cab5e56b8


Dithering: Integrated dithering patterns are projected onto the model's texture or base color, creating the illusion of discrete pixel blocks.

Jagged Outlines: Outlines are rendered with a deliberate "jagged" effect, further enhancing the retro pixel aesthetic.

This is achieved with minimal computational overhead, crucial for maintaining performance on mobile.

This shader offers flexibility, functioning as both a standard toon shader and a pixelated toon shader, adapting to various artistic styles and game requirements. Its efficiency makes it a viable solution for mobile development where performance is paramount.

I'm making this shader available for the community to use and adapt in their own projects.


How to Use:

Download the URPPixelated.shader file.

Import the file into your Unity project's Assets folder.

Create a new Material.

Assign the shader to the material by navigating to Custom/URPPixelatedToonOutlined.

I welcome feedback and encourage you to explore the possibilities this shader offers. 

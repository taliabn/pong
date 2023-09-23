# Pong
## About
This is a two-player implementation of Pong that is written from scratch in ARM assembly. 

## Special Effects:
### Audio
When the ball hits a surface, a beep is played. There is a different sound if a player loses a round
### Visual 
When a player loses a round, the screen smoothly fades from red to black. 

When the ball hits a surface, it changes to a (pseudo) random color
### Gameplay
When a player loses a round, their opponent's paddle grows in height
		
# Instructions
1. Go to https://cpulator.01xz.net/?sys=arm-de1soc in any browser.
2. Copy and paste the code from pong.s into the code editor pane in the center.
3. Click the Compile and Load button, at the top left of the Editor pane.
![Compile button in simulator](/images/compile.png)
4. In the Devices pane on the left, scroll down to 'VGA pixel buffer'. Click the dropdown, select "Show in a Seperate Box", and adjust the zoom to your preference.
![Moving pixel buffer window in simulator](/images/popout.png)
5. In the Devices pane on the left, scroll down to the first box that says "PS/2 keyboard or mouse". The "Type here" box is what players will use to control their paddles.
![Where to type in simulator during gamepay](/images/type-here.png)
6. At the top of the screen, press the "Continue" button to start the game. 
7. Click the keyboard input box described in step 5. Player 1 uses the 'w' and 's' keys to control the left paddle, and player 2 uses the up and down arrow keys to control the right paddle
8. The game is infinite, but players' scores are displayed as the game progresses. When you are done playing, at the top of the screen press the "Stop" button to end the game. 
9. Some browsers and machines are faster than others, which can affect gameplay. Game speed can be adjusted with the `RENDER_PAUSE_TIME` constant, which is set on line 19 in the code. If the game is too fast, increase it and conversely, if the game is too slow decrease it. Make sure to recompile after making any changes

Note: Due to the simulator, there will be some flickering in the graphics. This is normal.		

## Contact
Email: taliaben-naim2025@u.northwestern.edu

LinkedIn: [https://www.linkedin.com/in/talia-ben-naim](https://www.linkedin.com/in/talia-ben-naim)
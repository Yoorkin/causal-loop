"""Build an antialiased SVG atlas of upright, round-headed pictogram poses."""
import math
from pathlib import Path

frames = []
def pose(index):
    idle = index < 32
    walking = 32 <= index < 64
    rising = index == 64
    crouching = index >= 66
    crouch_walking = index >= 98
    phase = ((index - 66 if crouching else index) % 32) * math.tau / 32
    breath = math.sin(phase)
    swing, sweep = math.sin(phase), math.cos(phase)
    bob = breath * .35 if idle else (-abs(math.sin(phase * 2)) * .5 if walking else 0)
    lean = 0 if idle else .8
    hip = (12, 23 + bob * .5)
    shoulder = (12 + lean, 11.8 + bob)
    head = (12 + lean, 4.8 + bob)
    if crouching:
        bob = -abs(swing)*.3 if crouch_walking else breath*.15
        head, shoulder, hip = (14.6, 18.8+bob), (13, 25.8+bob), (8.8, 29.7+bob)
        step = swing*3 if crouch_walking else 0
        front_knee, rear_knee = (18.3+step*.4, 30.5), (7.5-step*.4, 32)
        front_foot = (15.3+step, 36-(max(0, sweep)*2 if crouch_walking else 0))
        rear_foot = (6.5-step, 36-(max(0, -sweep)*2 if crouch_walking else 0))
        front_elbow, front_hand = (18, 27.5+bob), (20-step*.2, 30+bob)
        rear_elbow, rear_hand = (8.5, 27+bob), (8-step*.2, 29.5+bob)
    elif idle:
        front_knee, front_foot = (14, 30), (14.5, 36)
        rear_knee, rear_foot = (9.5, 30), (9, 36)
        front_elbow, front_hand = (16.2, 16.4 + breath*.25), (16.8 + breath*.25, 21)
        rear_elbow, rear_hand = (7.8, 16.5 + breath*.25), (7.3 + breath*.25, 21)
    elif walking:
        front_lift, rear_lift = max(0, sweep)*5.5, max(0, -sweep)*5.5
        front_foot, rear_foot = (12 + swing*7, 36-front_lift), (12-swing*7, 36-rear_lift)
        front_knee = ((12+front_foot[0])/2 + .6, 29.5-front_lift*.5)
        rear_knee = ((12+rear_foot[0])/2 + .6, 29.5-rear_lift*.5)
        front_elbow, front_hand = (14-swing*3.5, 16+bob), (14-swing*6.5, 21+bob)
        rear_elbow, rear_hand = (10+swing*3.5, 16+bob), (10+swing*6.5, 21+bob)
    else:
        front_knee, front_foot = ((16, 27), (15, 32.5)) if rising else ((14, 29), (14.5, 36))
        rear_knee, rear_foot = ((9, 28), (7.5, 34)) if rising else ((9, 28), (8, 34))
        front_elbow, front_hand = (16, 14), (18, 13)
        rear_elbow, rear_hand = (8.5, 16), (7, 19)
    parts = []
    def path(points, width, color='#fff'):
        coords = ' '.join(f'{x:.3f},{y:.3f}' for x,y in points)
        parts.append(f'<polyline points="{coords}" fill="none" stroke="{color}" stroke-width="{width}" stroke-linecap="round" stroke-linejoin="round"/>')
    rear = '#bfbfbf'
    path([(shoulder[0]-1.8, shoulder[1]), rear_elbow, rear_hand], 3.0, rear)
    path([hip, rear_knee, rear_foot, (rear_foot[0]+1.8,rear_foot[1])], 3.5, rear)
    path([shoulder, hip], 5.0)
    path([hip, front_knee, front_foot, (front_foot[0]+1.8,front_foot[1])], 3.5)
    path([(shoulder[0]+1.8, shoulder[1]), front_elbow, front_hand], 3.0)
    # A detached circular head, with the eye inside its contour. No nose or snout.
    parts.append(f'<circle cx="{head[0]:.3f}" cy="{head[1]:.3f}" r="3.8" fill="#fff"/>')
    parts.append(f'<circle cx="{head[0]+1.65:.3f}" cy="{head[1]-.25:.3f}" r=".65" fill="#24343c"/>')
    return ''.join(parts)

# 16 columns of 32x48 logical tiles, rasterized by the browser at 4x resolution.
for index in range(130):
    x, y = (index % 16)*32 + 4, (index//16)*48 + 8
    frames.append(f'<g transform="translate({x} {y})">{pose(index)}</g>')
svg = '<svg xmlns="http://www.w3.org/2000/svg" width="2048" height="1728" viewBox="0 0 512 432">' + ''.join(frames) + '</svg>\n'
(Path(__file__).resolve().parents[1] / 'assets' / 'actors.svg').write_text(svg)

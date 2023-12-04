import pygame
import glob
import os
import time
import argparse


class View:
    def __init__(self, W=1920, H=1080, FPS=60, FS=16) -> None:
        self.width = W
        self.height = H
        self.fps = FPS
        self.save = False
        self.frame = 0
        self.fsize = FS

    def setup(self, title="AOC"):
        pygame.init()
        pygame.font.init()
        self.win = pygame.display.set_mode((self.width, self.height))
        pygame.display.set_caption(title)
        self.font = pygame.freetype.Font("vis/Inconsolata-SemiBold.ttf", self.fsize)
        self.font.origin = True
        self.clock = pygame.time.Clock()
        self.win.fill((0, 0, 0))

    def snaps(self):
        return "{}/frame_*.jpg".format(self.tmp_path)

    def record(self, output_path):
        self.save = True
        self.output_path = output_path
        self.tmp_path = os.path.dirname(output_path) + "/tmp/"
        for f in glob.glob(self.snaps()):
            os.remove(f)
        print("Recording video to: ", self.output_path)

    def render(self, controller):
        for object in controller.objects:
            object.update(self, controller)

        pygame.display.update()
        self.clock.tick(self.fps)

        if controller.animate:
            self.frame += 1
            if self.save:
                pygame.image.save(self.win, "{}/frame_{:04}.jpg".format(self.tmp_path, self.frame))

    def finish(self):
        if not self.save:
            return
        print("Now saving video")
        os.system("ffmpeg -r {} -i {}/frame_%04d.jpg {}".format(self.fps, self.tmp_path, self.output_path))
        print("Cleaning up snaps")
        for f in glob.glob(self.snaps()):
            os.remove(f)


class Controller:
    def __init__(self, start_anim=True) -> None:
        self.animate = start_anim
        self.quit = False
        self.objects = []
        self.clickables = []
        parser = argparse.ArgumentParser()
        parser.add_argument("-r", "--rec", help="record movie", action="store_true")
        parser.add_argument("-f", "--fps", help="set fps", type=int)
        self.args = parser.parse_args()

    def workdir(self):
        import __main__

        return os.path.dirname(os.path.dirname(os.path.realpath(__main__.__file__)))

    def basename(self):
        import __main__

        return os.path.splitext(os.path.basename(os.path.realpath(__main__.__file__)))[0]

    def add(self, object, clickable=False):
        self.objects.append(object)
        if clickable:
            self.clickables.append(object)

    def run(self, view):
        if self.args.rec:
            view.record(os.path.join(self.workdir(), self.basename() + ".mp4"))
        if self.args.fps:
            view.fps = self.args.fps
            print("Override FPS to: ", view.fps)
        pygame.event.clear()
        start = time.time()
        fcnt = 0
        while not self.quit:
            view.render(self)
            fcnt += 1
            for event in pygame.event.get():
                if event.type == pygame.QUIT:
                    self.quit = True
                if event.type == pygame.KEYDOWN:
                    if event.key == pygame.K_SPACE:
                        self.animate = not self.animate
                    if event.key == pygame.K_ESCAPE:
                        self.quit = True
                if event.type == pygame.MOUSEBUTTONDOWN:
                    pos = pygame.mouse.get_pos()
                    for obj in self.clickables:
                        obj.click(pos, True)
                if event.type == pygame.MOUSEBUTTONUP:
                    pos = pygame.mouse.get_pos()
                    for obj in self.clickables:
                        obj.click(pos, False)
            delta = time.time() - start
            if delta >= 3:
                print("FPS: {:02f}".format(fcnt / delta))
                fcnt = 0
                start = time.time()

        pygame.quit()
        view.finish()

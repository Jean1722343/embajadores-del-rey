"""Genera el ícono y los recursos de arranque a partir del escudo.

Uso (desde la raíz del proyecto):
    python herramientas/iconos.py
    dart run flutter_launcher_icons
"""
import glob
import os

import numpy as np
from PIL import Image, ImageFilter

RES = 'android/app/src/main/res'


def limpiar_motas(ruta):
    """Quita puntos sueltos del canal alfa (residuos del archivo original)."""
    im = Image.open(ruta).convert('RGBA')
    a = im.getchannel('A')
    solido = a.filter(ImageFilter.MinFilter(9)).filter(ImageFilter.MaxFilter(13))
    im.putalpha(Image.fromarray(np.minimum(np.asarray(a), np.asarray(solido))))
    im.save(ruta, optimize=True)


def con_filete(src, alto, grosor):
    """Escudo a la altura dada con un filete blanco alrededor."""
    ancho = round(src.width * alto / src.height)
    im = src.resize((ancho, alto), Image.LANCZOS)
    m = grosor * 2
    lienzo = Image.new('RGBA', (ancho + m * 2, alto + m * 2), (0, 0, 0, 0))
    lienzo.alpha_composite(im, (m, m))
    a = (lienzo.getchannel('A')
         .filter(ImageFilter.GaussianBlur(grosor * 0.6))
         .point(lambda v: 255 if v > 18 else 0)
         .filter(ImageFilter.GaussianBlur(1.2)))
    blanco = Image.new('RGBA', lienzo.size, (255, 255, 255, 0))
    blanco.putalpha(a)
    blanco.alpha_composite(lienzo)
    return blanco


def fondo(n):
    """Fondo blanco, como se presenta el escudo oficial."""
    return Image.new('RGBA', (n, n), (255, 255, 255, 255))


def simple(src, alto):
    """Escudo a la altura dada, sin filete."""
    return src.resize((round(src.width * alto / src.height), alto), Image.LANCZOS)


def centrar(base, escudo):
    base.alpha_composite(escudo, ((base.width - escudo.width) // 2, (base.height - escudo.height) // 2))
    return base


def main():
    for ruta in glob.glob('assets/emblema/escudo_*.png'):
        limpiar_motas(ruta)
    src = Image.open('assets/emblema/escudo_4_embajador.png').convert('RGBA')
    src = src.crop(src.getbbox())
    vacio = lambda n: Image.new('RGBA', (n, n), (0, 0, 0, 0))

    os.makedirs('assets/icono', exist_ok=True)
    centrar(fondo(1024), simple(src, 700)).convert('RGB').save('assets/icono/icono.png')
    fondo(1024).convert('RGB').save('assets/icono/icono_fondo.png')
    centrar(vacio(1024), simple(src, 540)).save('assets/icono/icono_frente.png')

    # Arranque nativo: el escudo azul solo (etapa de Paje), en el lienzo
    # completo de 1200x1500 para que coincida con el primer cuadro de la
    # pantalla de carga de Flutter (172 dp de alto, centrado).
    paje = Image.open('assets/emblema/escudo_1_paje.png').convert('RGBA')
    alto = 688  # 172 dp en xxxhdpi
    paje = paje.resize((round(paje.width * alto / paje.height), alto), Image.LANCZOS)
    os.makedirs(f'{RES}/drawable-xxxhdpi', exist_ok=True)
    centrar(vacio(1152), paje).save(f'{RES}/drawable-xxxhdpi/arranque_escudo.png', optimize=True)
    paje.save(f'{RES}/drawable-xxxhdpi/arranque_escudo_plano.png', optimize=True)


if __name__ == '__main__':
    main()

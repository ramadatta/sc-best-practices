setwd("/home/ramadatta/Documents/sc-bestpractices/af_xmpl_run/")

import pyroe

quant_dir = 'quant'
anndata = pyroe.load_fry(quant_dir)

import pyroe

quant_dir = 'quant'
anndata = pyroe.load_fry(quant_dir, output_format={'X' : ['U','S','A']})

.. riskParityPortfolio documentation master file, created by
   sphinx-quickstart on Sat Nov 10 08:44:52 2018.
   You can adapt this file completely to your liking, but it should at least
   contain the root `toctree` directive.

Welcome to riskParityPortfolio!
===============================

``riskParityPortfolio`` allows users to design portfolios that meet the risk parity criteria.
We solve the underlying optimization problem using two approaches: 1) applying general non linear
constrained optimization solvers such as ``alabama`` and ``slsqp``, and 2) applying the successive
convex approximation (SCA) described in
`Feng & Palomar (2016) <http://www.ece.ust.hk/~palomar/Publications_files/2015/FengPalomar-TSP2015%20-%20risk_parity_portfolio.pdf>`_.

See the `Getting started <_static/getting_started.html>`_ tutorial for a comparison
between approaches.

Installation
------------

The *stable* release of ``riskParityPortfolio`` can be installed from CRAN as simple as:

.. highlight:: r

::

   > install.packages("riskParityPortfolio")

whereas the *development* version can be installed from GitHub as follows:

.. highlight:: r

::

   > devtools::install_github("dppalomar/riskParityPortfolio")
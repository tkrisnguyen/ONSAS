%md# Reconfiguration cantilever beam example
%md
%md [![Octave script](https://img.shields.io/badge/script-url-blue)](https://github.com/ONSAS/ONSAS.m/blob/master/examples/dragBeamReconfiguration/dragBeamReconfiguration.m)
%md
%md In this tutorial, a cantilever beam submitted to a flow producing drag forces is considered. The main goal is to validate drag forces considering reconfiguration in a problem with large displacements. The example is based on one of the problems considered in [this reference](https://www.cambridge.org/core/journals/journal-of-fluid-mechanics/article/drag-reduction-of-flexible-plates-by-reconfiguration/A3A066DE3886C40B1463508C92D1C81D), where a reference solution is presented and validated with experimental data. The reference solution was generated with the code publicly available in [this repository](https://github.com/lm2-poly/Reconfiguration-Beam/blob/master/reconfiguration.m)
%md
%md The problem consists in a cantilever beam submitted to a fluid flow with uniform velocity $\bfv_a(\bfx,t) = v_a(t) \bfc_2$, as shown int he Figure bellow. The beam is clamped on the boundary at $x=0$ m, and the span length is $L$. The cross-section of the beam is circular with diameter $d$, and the chord length used to compute the aerodynamic forces is $d_c=d$. For the material of the beam a linear elastic isotropic model is considered, with Young modulus $E$ density $\rho$ 
%md
%md```@raw html
%md<img src="../../assets/dragBeamReconfiguration/ilus.svg" alt="general sketch" width="700"/>
%md```
%md## Dimensionless analysis
%md--------------------
%md
%
%mdThe problem can be studied through the following dimensionless numbers: 
%md
%md```math 
%md c_y = \frac{\rho_f L^3 v_a^2}{16 E I_{zz}}, \qquad \mathcal{R} = \frac{F}{\frac{1}{2}\rho_f L d c_d v_a^2}
%md```
%md where  $F$ is the global drag force towards $\bfc_2$, $c_y$ is the Cauchy number that describes the ratio between the stiffness of the beam and the flow load and the reconfiguration number $\mathcal{R}$ reflects the geometric nonlinear effect by dividing the drag of the flexible beam to that of a rigid one of the same geometry
%md## Numerical solution
%md---------------------
%md Before the workspace is cleaned and the ONSAS directory is added:
close all, if ~strcmp( getenv('TESTS_RUN'), 'yes'), clear all, end
% add dynamic case boolean for non test executions: 
testBool = true; 
% add path
addpath( genpath( [ pwd '/../../src'] ) ); 
%----------------------------
%md
%md Geometrical dimensions sketched in Fig 1 are loaded:
[L, d, Izz, E, nu, rhoS, rhoF, nuF, dragCoefFunction, NR, cycd_vec, uy_vec ] = loadParametersCirc();
%md where $rho_f$ and $rho_s$ are the fluid and solid densities respectively, $nu$ is the fluid kinematic viscosity, $dragCoefFunction$ is the user-defined drag coefficient function to compute the drag forces, $NR$ is the number of load steps (or velocity cases solved)
%md
%md
%md the number of elements employed to discretize the beam is:
numElements = 10 ;
%md
%md### MEBI parameters
%md
%md### materials
%md Since the example contains only one material and co-rotational strain element so then `materials` struct is:
materials  = struct();
materials.hyperElasModel  = '1DrotEngStrain' ;
materials.hyperElasParams = [ E nu ]         ;
materials.density         = rhoS             ;
%md
%md### elements
%md
%md Two different types of elements are considered, node and frames. The nodes will be assigned in the first entry (index $1$) and the beam at the index $2$. The _elemType_ field is then:
elements(1).elemType = 'node'  ;
elements(2).elemType = 'frame' ;
%md for the geometries, the node has not geometry to assign (empty array), and frame elements will be set as a circular section with $d$ diameter.
elements(2).elemCrossSecParams{1,1} = 'circle' ;
elements(2).elemCrossSecParams{2,1} = [ d ] ;
%md where the aerodynamic coefficents and the chord vector are set by default for circular cross sections. In the first case we want to consider a different drag function so:   
elements(2).dragCoefFunction = "dragCircular"
%md The geometrical non-linear effects are considered in this case to compute the aerodynamic force:
geometricNonLinearAero = true ;
numGaussPoints = 4 ;
computeAeroTangMatrix = true ;
elements(2).aeroNumericalParams = {numGaussPoints, computeAeroTangMatrix, geometricNonLinearAero} ;
%md
%md### boundaryConds
%md
%md Only one welded (6 degrees of freedom are set to zero) boundary condition (BC) is considered:
boundaryConds(1).imposDispDofs = [ 1 2 3 4 5 6 ] ;
boundaryConds(1).imposDispVals = [ 0 0 0 0 0 0 ] ;
%md
%md### initial Conditions
%md Any non-homogeneous initial condition (IC) are set for this case, then an empty struct is used:
initialConds = struct() ;
%md
%md### mesh parameters
%mdThe coordinates of the mesh nodes are given by the matrix:
mesh.nodesCoords = [ (0:(numElements))' * L/numElements  zeros(numElements+1,2) ] ;
%mdThe connectivity is introduced using the _conecCell_. Each entry of the cell contains a vector with the four indexes of the MEBI parameters, followed by the indexes of nodes that compose the element (node connectivity). For didactical purposes each element entry is commented. First the cell is initialized:
mesh.conecCell = { } ;
%md then the first welded node is defined with material (M) zero since nodes don't have material, the first element (E) type (the first entry of the `elements` struct), and (B) is the first entry of the the `boundaryConds` struct. Finally the node is assigned:
mesh.conecCell{ 1, 1 } = [ 0 1 1   1 ] ;
%md Next the frame elements MEB parameters are set. The frame material is the first material of `materials` struct, then $1$ is assigned. The second entry of the `elements` struct correspond to the frame element employed, so $2$ is set. Finally no BC is required for this element, then $0$ is used.  Consecutive nodes build the element so then the `mesh.conecCell` is:
for i=1:numElements,
  mesh.conecCell{ i+1,1 } = [ 1 2 0   i i+1 ] ;
end
%md
%md### analysisSettings
%md
%md The fluid properties are set into _fluidProps_ field into `analysisSettings` struct. In this field the fluid velocity, viscosity and density are defined, This will apply a external fluid loads according to the quasi-steady theory for each element with aerodynamic coefficients fields into the `elements` struct. The name of the fluid velocity function located on the same example path is introduced as a string 'windVelCircStatic': 
analysisSettings.fluidProps = {rhoF; nuF; 'windVelCircStatic'} ;
%md since this problem is static, then a N-R method is employed. The convergence of the method is accomplish with ten equal load steps. The time variable for static cases is a load factor parameter that must be configured into the `windVel.m` function. A linear profile is considered for ten equal velocity load steps as:
analysisSettings.deltaT        =   1            ;
analysisSettings.finalTime     =   NR            ;
analysisSettings.methodName    = 'newtonRaphson' ;
%md Next the maximum number of iterations per load(time) step, the residual force and the displacements tolerances are set to (if null tolerance is set the criterion is not considered): 
analysisSettings.stopTolDeltau =   0             ;
analysisSettings.stopTolForces =   1e-8          ;
analysisSettings.stopTolIts    =   50            ;
%md
%md### otherParams
%md The name of the problem and vtk format output are selected: 
otherParams  = struct();
otherParams.problemName = 'staticReconfigurationCircle';
otherParams.plots_format = 'vtk' ;
%md
%md### Case 1: validation case with constant $c_d = 1.2$
%md
%md The ONSAS software is executed for the parameters above defined and the displacement solution of each load(time) step is saved in `matUsCase1`matrix:
%md 
%md The reaction forces at $x=0$ are stored  in the following vector and declaring a global variable:
global globalReactionForces
globalReactionForces = zeros(6*analysisSettings.finalTime, 1) ;
%md 
%md The node index where the reaction are computed is:
global glboalNodeReactionForces
glboalNodeReactionForces = 1 ;
%
% Run ONSAS 
%
[matUs] = ONSAS( materials, elements, boundaryConds, initialConds, mesh, analysisSettings, otherParams ) ;
%
%### Numeric solution
%
% The numerical solution is extracted. First the reference coordinaes
xref = mesh.nodesCoords(:,1) ;
yref = mesh.nodesCoords(:,2) ;
zref = mesh.nodesCoords(:,3) ;
%md 
%md## Verification
%md---------------------
% Compute the values of R and CyCd:
numLoadSteps = size(matUs, 2) ;
timeVec = linspace(0,analysisSettings.finalTime, numLoadSteps) ;
% initialize vectors
Cy = zeros(numLoadSteps-1, 1)                 ;
R  = zeros(numLoadSteps-1, 1)                 ;
C_d = feval( elements(2).dragCoefFunction, 0 , 0) ;
% fill them
for windVelStep = 1:numLoadSteps - 1
    % Compute dimensionless magnitudes 
    windVel         = feval( analysisSettings.fluidProps{3,:}, 0, timeVec(windVelStep + 1 ) ) ;
    normWindVel     = norm( windVel )                                                         ;
    dirWindVel      = windVel / normWindVel                                                   ;
    Cy(windVelStep) =  1/2 * rhoF * normWindVel^2 * (L)^3 *d / (E*Izz)                        ;

    % numeric drag 
    FReaction = globalReactionForces((windVelStep-1)*6 + 1: windVelStep*6) ;
    FDragi = FReaction(3)                                                  ;    
    FDRef  = 1/2 * rhoF * normWindVel^2 * C_d * d * L ;
    R(windVelStep) =  abs(FDragi)/(FDRef )            ;

end
%md
%md### Case 2: case with drag coefficient formula proposed in [this reference](https://ascelibrary.org/doi/10.1061/%28ASCE%29HY.1943-7900.0000722) 
%
%### Plots
%




%
%### Gosselin et.Al 2010 solution
%
% resudrag (cycd, R) and def wich contains de deformed configuration for 10^i cycyd values: 
base_dir='';
if strcmp( getenv('TESTS_RUN'),'yes') && isfolder('examples'),
  base_dir=['.' filesep 'examples' filesep 'dragBeamReconfiguration' filesep];
end
load( [base_dir 'Gosselin2010_data.mat'], 'def', 'resudrag')
%md
%md### Validation plots
%md
%md The plot parameters are:
lw = 4 ; ms = 5 ;
axislw = 1  ; axisFontSize = 20 ; legendFontSize = 15 ; curveFontSize = 15 ;
Gline = 'k-'; ONSASline = 'bo'  ;     
folderPathFigs = './output/figs/' ;
mkdir(folderPathFigs) ;
%md The modified Cauchy number vs R is plotted:  
fig1 = figure(1) ;
hold on
loglog(C_d*Cy       , R             , ONSASline , 'linewidth', lw, 'markersize', ms ) ;
loglog(resudrag(:,1), resudrag(:,2) , Gline     , 'linewidth', lw, 'markersize', ms ) ;
% add legend
legend('ONSAS', 'Gosselin2010')
% set labels legend
labx=xlabel(' Cy* ');    laby=ylabel('R');
set(legend, 'linewidth', axislw, 'fontsize', legendFontSize, 'location','northEast' ) ;
% set fonts
set(gca, 'linewidth', axislw, 'fontsize', curveFontSize ) ;
set(labx, 'FontSize', axisFontSize); set(laby, 'FontSize', axisFontSize) ;
grid on
% save figure
namefig1 = strcat(folderPathFigs, 'CyR.png') ;
% print(namefig1,'-dpng')
%
%md The modified Cauchy number vs R is plotted:  
%
fig3 = figure(3) ;
hold on
plot(xref, yref  , 'k--' , 'linewidth', lw, 'markersize', ms   );
for nr = 1:NR 
  % Numerical deformed coordinates solution
  xdef = xref + matUs(1:6:end,nr+1) ;
  ydef = yref + matUs(3:6:end,nr+1) ;
  zdef = zref + matUs(5:6:end,nr+1) ;
  thetaXdef = matUs(2:6:end,nr+1)   ;
  thetaYdef = matUs(4:6:end,nr+1)   ;
  thetaZdef = matUs(6:6:end,nr+1)   ;
  % Gosselin deformed coordinates solution
  xdefG = def(1,:,nr)               ;
  ydefG = -def(2,:,nr)              ;
  % Plot 
  plot(xdef ,  ydef,  ONSASline, 'linewidth', lw, 'markersize', ms );
  plot(xdefG, ydefG,  Gline    , 'linewidth', lw, 'markersize', ms );
end
% add legend
legend('Gosselin2010', 'ONSAS')
labx=xlabel('x [m]');    laby=ylabel('y [m]');
% set fonts
set(legend, 'linewidth', axislw, 'fontsize', legendFontSize, 'location','northEast' ) ;
set(gca, 'linewidth', axislw, 'fontsize', curveFontSize ) ;
set(labx, 'FontSize', axisFontSize); set(laby, 'FontSize', axisFontSize) ;
grid on
axis equal
% save fig
namefig3 = strcat(folderPathFigs, 'xy.png') ;
% print(namefig3,'-dpng')
%
%### Verification boolean
%
% The verification boolean is computed as for the deformed configurations and the cycd curve
% deformed coordinates dif norm
vecDifDeform =  [ norm( ydef - ydefG(1:numElements*10:end)') ;...
                  norm( xdef - xdefG(1:numElements*10:end)') ] ;

% verification boolean deformed 
verifBooleanDef =  vecDifDeform <=  2e-2 * L ;
% cycd vs R verification boolean is: 
verifBooleanR = abs(R(end) - resudrag(end,2) ) <  5e-3 ;
% The example verifboolean is:
verifBoolean = verifBooleanR && all(verifBooleanDef)
if ~testBool
  %
  % Dynamic Case
  %----------------------------
  %
  % since this case is highly dynamic the tangent matrix of the aerodynamic force 
  % vector is not necessary 
  %
  % elements
  %----------------------------
  elements(2).massMatType = 'consistent'                                        ;
  computeAeroTangentMatrix = false                                              ;
  elements(2).elemTypeAero   = [0 d 0 numGaussPoints computeAeroTangentMatrix ] ;
  %
  % analysisSettings Dynamic
  %----------------------------
  analysisSettings.fluidProps = {rhoF; nuF; 'windVelCircDynamic'}             ;
  analysisSettings.finalTime     =   4                                        ;
  analysisSettings.deltaT        =   0.0025                                   ;
                                       
  numTimeSteps  = round(analysisSettings.finalTime / analysisSettings.deltaT) ;
  analysisSettings.methodName    = 'newmark'                                  ;
  analysisSettings.stopTolDeltau =   1e-11                                    ;
  analysisSettings.stopTolForces =   1e-6                                     ;
  analysisSettings.stopTolIts    =   15                                       ;
  %
  % otherParams
  %----------------------------
  otherParams.problemName = 'dynamicReconfigurationCircle';
  %
  % Run ONSAS 
  %
  [matUs] = ONSAS( materials, elements, boundaryConds, initialConds, mesh, analysisSettings, otherParams ) ;

end
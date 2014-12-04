#include "DFImprovedSolver.h"
#include <solvers/NavierStokes/kernels/generateQT.h>
#include <cusp/io/matrix_market.h>
#include <cusp/blas.h>

template <typename memoryType>
DFImprovedSolver<memoryType>::DFImprovedSolver(parameterDB *pDB, domain *dInfo)
{
	NavierStokesSolver<memoryType>::paramDB = pDB;
	NavierStokesSolver<memoryType>::domInfo = dInfo;
}

template <typename memoryType>
void DFImprovedSolver<memoryType>::generateC()
{
	int nx = NavierStokesSolver<memoryType>::domInfo->nx,
	    ny = NavierStokesSolver<memoryType>::domInfo->ny;
	
	parameterDB  &db = *NavierStokesSolver<memoryType>::paramDB;
	real         dt  = db["simulation"]["dt"].get<real>();

	const int ii = 2, jj = 2;
	const int N_u = (nx-1)*ny;
	
	int  isColumnNonZero[5][5];
	for(int m=-2; m<=2; m++)
	{
		for(int l=-2; l<=2; l++)
		{
			isColumnNonZero[jj+m][ii+l]=0;
		}
	}

	int num_nonzeros = 0;
	for(int j=0; j<ny; j++)
	{
		for(int i=0; i<nx; i++)
		{
			if(j>0)
			{
				int I = (j-1)*nx+i+N_u;
				if(DirectForcingSolver<memoryType>::tags[I]==-1)
				{
					isColumnNonZero[jj-1][ii] += 1;
					isColumnNonZero[jj][ii]   += 1;
				}
				else
				{
					int diff = DirectForcingSolver<memoryType>::tags[I]-I;
					if(diff < -1)
					{
						isColumnNonZero[jj-2][ii] += 1;
						isColumnNonZero[jj-1][ii] += 1;
					}
					else if(diff == -1)
					{
						isColumnNonZero[jj-1][ii-1] += 1;
						isColumnNonZero[jj][ii-1]   += 1;
					}
					else if(diff == 1)
					{
						isColumnNonZero[jj-1][ii+1] += 1;
						isColumnNonZero[jj][ii+1]   += 1;
					}
					else if(diff > 1)
					{
						isColumnNonZero[jj][ii]   += 1;
						isColumnNonZero[jj+1][ii] += 1;
					}
				}
			}
			if(i>0)
			{
				int I = j*(nx-1)+(i-1);
				if(DirectForcingSolver<memoryType>::tags[I]==-1)
				{
					isColumnNonZero[jj][ii-1] += 1;
					isColumnNonZero[jj][ii]   += 1;
				}
				else
				{
					int diff = DirectForcingSolver<memoryType>::tags[I]-I;
					if(diff < -1)
					{
						isColumnNonZero[jj-1][ii-1] += 1;
						isColumnNonZero[jj-1][ii]   += 1;
					}
					else if(diff == -1)
					{
						isColumnNonZero[jj][ii-2] += 1;
						isColumnNonZero[jj][ii-1] += 1;
					}
					else if(diff == 1)
					{
						isColumnNonZero[jj][ii]   += 1;
						isColumnNonZero[jj][ii+1] += 1;
					}
					else if(diff > 1)
					{
						isColumnNonZero[jj+1][ii-1] += 1;
						isColumnNonZero[jj+1][ii]   += 1;
					}
				}
			}
			if(i<nx-1)
			{
				int I = j*(nx-1)+i;
				if(DirectForcingSolver<memoryType>::tags[I]==-1)
				{
					isColumnNonZero[jj][ii+1] += 1;
					isColumnNonZero[jj][ii]   += 1;
				}
				else
				{
					int diff = DirectForcingSolver<memoryType>::tags[I]-I;
					if(diff < -1)
					{
						isColumnNonZero[jj-1][ii+1] += 1;
						isColumnNonZero[jj-1][ii]   += 1;
					}
					else if(diff == -1)
					{
						isColumnNonZero[jj][ii] += 1;
						isColumnNonZero[jj][ii-1] += 1;
					}
					else if(diff == 1)
					{
						isColumnNonZero[jj][ii+2] += 1;
						isColumnNonZero[jj][ii+1] += 1;
					}
					else if(diff > 1)
					{
						isColumnNonZero[jj+1][ii+1] += 1;
						isColumnNonZero[jj+1][ii]   += 1;
					}
				}
			}
			if(j<ny-1)
			{
				int I = j*nx+i+N_u;
				if(DirectForcingSolver<memoryType>::tags[I]==-1)
				{
					isColumnNonZero[jj+1][ii] += 1;
					isColumnNonZero[jj][ii]   += 1;
				}
				else
				{
					int diff = DirectForcingSolver<memoryType>::tags[I]-I;
					if(diff < -1)
					{
						isColumnNonZero[jj][ii]   += 1;
						isColumnNonZero[jj-1][ii] += 1;
					}
					else if(diff == -1)
					{
						isColumnNonZero[jj+1][ii-1] += 1;
						isColumnNonZero[jj][ii-1]   += 1;
					}
					else if(diff == 1)
					{
						isColumnNonZero[jj+1][ii+1] += 1;
						isColumnNonZero[jj][ii+1]   += 1;
					}
					else if(diff > 1)
					{
						isColumnNonZero[jj+2][ii] += 1;
						isColumnNonZero[jj+1][ii] += 1;
					}
				}
			}
			int numNonZeroColumns = 0;
			//std::cout << "(" << i << "," << j << ")|";
			for(int m=-2; m<=2; m++)
			{
				for(int l=-2; l<=2; l++)
				{
					//std::cout << isColumnNonZero[jj+m][ii+l] << ",";
					if(isColumnNonZero[jj+m][ii+l]) numNonZeroColumns++;
					isColumnNonZero[jj+m][ii+l] = 0;
				}
				//std::cout << "|";
			}
			//std::cout << numNonZeroColumns << std::endl;
			num_nonzeros += numNonZeroColumns;
		}
	}
	//std::cout << "Total nonzeros: " << num_nonzeros << std::endl;

	CHost.resize(nx*ny, nx*ny, num_nonzeros);

	real valuesInColumns[5][5];

	for(int m=-2; m<=2; m++)
	{
		for(int l=-2; l<=2; l++)
		{
			valuesInColumns[jj+m][ii+l]=0.0;
		}
	}

	int idx = 0;
	for(int j=0; j<ny; j++)
	{
		for(int i=0; i<nx; i++)
		{
			if(j>0)
			{
				int I = (j-1)*nx+i+N_u;
				if(DirectForcingSolver<memoryType>::tags[I]==-1)
				{
					isColumnNonZero[jj-1][ii] += 1;
					valuesInColumns[jj-1][ii] -= 1.0;
					isColumnNonZero[jj][ii]   += 1;
					valuesInColumns[jj][ii]   += 1.0;
				}
				else
				{
					int diff = DirectForcingSolver<memoryType>::tags[I]-I;
					real xi = DirectForcingSolver<memoryType>::coeffs[I];
					if(diff < -1)
					{
						isColumnNonZero[jj-2][ii] += 1;
						valuesInColumns[jj-2][ii] -= xi;
						isColumnNonZero[jj-1][ii] += 1;
						valuesInColumns[jj-1][ii] += xi;
					}
					else if(diff == -1)
					{
						isColumnNonZero[jj-1][ii-1] += 1;
						valuesInColumns[jj-1][ii-1] -= xi;
						isColumnNonZero[jj][ii-1]   += 1;
						valuesInColumns[jj][ii-1]   += xi;
					}
					else if(diff == 1)
					{
						isColumnNonZero[jj-1][ii+1] += 1;
						valuesInColumns[jj-1][ii+1] -= xi;
						isColumnNonZero[jj][ii+1]   += 1;
						valuesInColumns[jj][ii+1]   += xi;
					}
					else if(diff > 1)
					{
						isColumnNonZero[jj][ii]   += 1;
						valuesInColumns[jj][ii]   -= xi;
						isColumnNonZero[jj+1][ii] += 1;
						valuesInColumns[jj+1][ii] += xi;
					}
				}
			}
			if(i>0)
			{
				int I = j*(nx-1)+(i-1);
				if(DirectForcingSolver<memoryType>::tags[I]==-1)
				{
					isColumnNonZero[jj][ii-1] += 1;
					valuesInColumns[jj][ii-1] -= 1.0;
					isColumnNonZero[jj][ii]   += 1;
					valuesInColumns[jj][ii]   += 1.0;
				}
				else
				{
					int diff = DirectForcingSolver<memoryType>::tags[I]-I;
					real xi = DirectForcingSolver<memoryType>::coeffs[I];
					if(diff < -1)
					{
						isColumnNonZero[jj-1][ii-1] += 1;
						valuesInColumns[jj-1][ii-1] -= xi;
						isColumnNonZero[jj-1][ii]   += 1;
						valuesInColumns[jj-1][ii]   += xi;
					}
					else if(diff == -1)
					{
						isColumnNonZero[jj][ii-2] += 1;
						valuesInColumns[jj][ii-2] -= xi;
						isColumnNonZero[jj][ii-1] += 1;
						valuesInColumns[jj][ii-1] += xi;
					}
					else if(diff == 1)
					{
						isColumnNonZero[jj][ii]   += 1;
						valuesInColumns[jj][ii]   -= xi;
						isColumnNonZero[jj][ii+1] += 1;
						valuesInColumns[jj][ii+1] += xi;
					}
					else if(diff > 1)
					{
						isColumnNonZero[jj+1][ii-1] += 1;
						valuesInColumns[jj+1][ii-1] -= xi;
						isColumnNonZero[jj+1][ii]   += 1;
						valuesInColumns[jj+1][ii]   += xi;
					}
				}
			}
			if(i<nx-1)
			{
				int I = j*(nx-1)+i;
				if(DirectForcingSolver<memoryType>::tags[I]==-1)
				{
					isColumnNonZero[jj][ii+1] += 1;
					valuesInColumns[jj][ii+1] -= 1.0;
					isColumnNonZero[jj][ii]   += 1;
					valuesInColumns[jj][ii]   += 1.0;
				}
				else
				{
					int diff = DirectForcingSolver<memoryType>::tags[I]-I;
					real xi = DirectForcingSolver<memoryType>::coeffs[I];
					if(diff < -1)
					{
						isColumnNonZero[jj-1][ii+1] += 1;
						valuesInColumns[jj-1][ii+1] -= xi;
						isColumnNonZero[jj-1][ii]   += 1;
						valuesInColumns[jj-1][ii]   += xi;
					}
					else if(diff == -1)
					{
						isColumnNonZero[jj][ii]   += 1;
						valuesInColumns[jj][ii]   -= xi;
						isColumnNonZero[jj][ii-1] += 1;
						valuesInColumns[jj][ii-1] += xi;
					}
					else if(diff == 1)
					{
						isColumnNonZero[jj][ii+2] += 1;
						valuesInColumns[jj][ii+2] -= xi;
						isColumnNonZero[jj][ii+1] += 1;
						valuesInColumns[jj][ii+1] += xi;
					}
					else if(diff > 1)
					{
						isColumnNonZero[jj+1][ii+1] += 1;
						valuesInColumns[jj+1][ii+1] -= xi;
						isColumnNonZero[jj+1][ii]   += 1;
						valuesInColumns[jj+1][ii]   += xi;
					}
				}
			}
			if(j<ny-1)
			{
				int I = j*nx+i+N_u;
				if(DirectForcingSolver<memoryType>::tags[I]==-1)
				{
					isColumnNonZero[jj+1][ii] += 1;
					valuesInColumns[jj+1][ii] -= 1.0;
					isColumnNonZero[jj][ii]   += 1;
					valuesInColumns[jj][ii]   += 1.0;
				}
				else
				{
					int diff = DirectForcingSolver<memoryType>::tags[I]-I;
					real xi = DirectForcingSolver<memoryType>::coeffs[I];
					if(diff < -1)
					{
						isColumnNonZero[jj][ii]   += 1;
						valuesInColumns[jj][ii]   -= xi;
						isColumnNonZero[jj-1][ii] += 1;
						valuesInColumns[jj-1][ii] += xi;
					}
					else if(diff == -1)
					{
						isColumnNonZero[jj+1][ii-1] += 1;
						valuesInColumns[jj+1][ii-1] -= xi;
						isColumnNonZero[jj][ii-1]   += 1;
						valuesInColumns[jj][ii-1]   += xi;
					}
					else if(diff == 1)
					{
						isColumnNonZero[jj+1][ii+1] += 1;
						valuesInColumns[jj+1][ii+1] -= xi;
						isColumnNonZero[jj][ii+1]   += 1;
						valuesInColumns[jj][ii+1]   += xi;
					}
					else if(diff > 1)
					{
						isColumnNonZero[jj+2][ii] += 1;
						valuesInColumns[jj+2][ii] -= xi;
						isColumnNonZero[jj+1][ii] += 1;
						valuesInColumns[jj+1][ii] += xi;
					}
				}
			}
			int row = j*nx+i;
			for(int m=-2; m<=2; m++)
			{
				for(int l=-2; l<=2; l++)
				{
					if(isColumnNonZero[jj+m][ii+l])
					{
						CHost.row_indices[idx] = row;
						CHost.column_indices[idx] = row + m*nx + l;
						CHost.values[idx] = valuesInColumns[jj+m][ii+l];
						if(CHost.row_indices[idx]==(ny/2)*nx+nx/2 && CHost.row_indices[idx]==CHost.column_indices[idx])
						{
							CHost.values[idx]+=CHost.values[idx];
						}
						idx++;
					}
					isColumnNonZero[jj+m][ii+l] = 0;
					valuesInColumns[jj+m][ii+l] = 0.0;
				}
			}
		}
	}
	CHost.sort_by_row_and_column();
	CHost.values[0] += CHost.values[0];
	NavierStokesSolver<memoryType>::C = CHost;
	cusp::io::write_matrix_market_file(NavierStokesSolver<memoryType>::C, "C.mtx");
	cusp::blas::scal(NavierStokesSolver<memoryType>::C.values, dt);
}

/*
template <typename memoryType>
void DFImprovedSolver<memoryType>::generateQT()
{
	NavierStokesSolver<memoryType>::generateQT();
	DirectForcingSolver<memoryType>::updateQ();
	updateQT();
	cusp::io::write_matrix_market_file(NavierStokesSolver<memoryType>::Q, "Q.mtx");
	cusp::io::write_matrix_market_file(NavierStokesSolver<memoryType>::QT, "QT.mtx");
}

template <>
void DFImprovedSolver<host_memory>::updateQT()
{
}

template <>
void DFImprovedSolver<device_memory>::updateQT()
{
	const int blocksize = 256;
	
	int  nx = domInfo->nx,
	     ny = domInfo->ny;
	
	int  QTSize = 4*nx*ny-2*(nx+ny);
	
	int  *QTRows = thrust::raw_pointer_cast(&(QT.row_indices[0])),
	     *QTCols = thrust::raw_pointer_cast(&(QT.column_indices[0]));
	int  *tags_r = thrust::raw_pointer_cast(&(tagsD[0]));
	real *coeffs_r = thrust::raw_pointer_cast(&(coeffsD[0]));

	real *QTVals = thrust::raw_pointer_cast(&(QT.values[0]));
	
	dim3 dimGrid( int((QTSize-0.5)/blocksize) + 1, 1);
	dim3 dimBlock(blocksize, 1);
	
	kernels::updateQT <<<dimGrid, dimBlock>>> (QTRows, QTCols, QTVals, QTSize, tags_r, coeffs_r);
}
*/

template class DFImprovedSolver<host_memory>;
template class DFImprovedSolver<device_memory>;